#if UNITY_EDITOR
using UnityEditor;
#endif
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

[ExecuteAlways]
public class CameraColorSpaceWorkaround : MonoBehaviour
{
    public bool workaroundIsEnabled = true;
    
    public Material material;
    public Camera cameraUI;
    public Camera camera3D;
    public RenderPassEvent blendEvent = RenderPassEvent.AfterRenderingPostProcessing;
    
    private RenderTexture m_CameraUIRT;
    private const string k_CameraUIRTName = "_CameraUIRT";
    private UniversalAdditionalCameraData m_CameraUIAddData;
    private CameraColorSpaceWorkaroundPass m_Pass;
    private const string k_EnabledName = "_CameraColorSpaceWorkaroundEnabled";
    
    private void OnValidate()
    {
        Setup();
    }
    private void OnEnable()
    {
        Setup();
    }
    
    private void OnDisable()
    {
        Cleanup();
    }

    private void Setup()
    {
        // Clean up first
        Cleanup();
        
        if (cameraUI == null || camera3D == null || material == null) return;
        
        // Change UI camera settings
        if(m_CameraUIAddData == null) m_CameraUIAddData = cameraUI.GetUniversalAdditionalCameraData();
        cameraUI.depth = camera3D.depth - 1; //Make UI cam render first
        cameraUI.clearFlags = CameraClearFlags.SolidColor;
        cameraUI.backgroundColor = new Color(0,0,0,0);
        m_CameraUIAddData.renderType = CameraRenderType.Base; //So that we can set target texture
        
        // Create a RenderTexture and use it as UI camera's target
        if (m_CameraUIRT == null || !m_CameraUIRT.IsCreated())
        {
            // Create a RenderTexture and use it as camera target
            UniversalRenderPipeline.InitializeCameraDataWrapper(
                cameraUI, m_CameraUIAddData, true, 
                out var cameraDataTop);
            var descTop = cameraDataTop.cameraTargetDescriptor;
            descTop.graphicsFormat = UniversalRenderPipeline.MakeRenderTextureGraphicsFormat(
                cameraDataTop.isHdrEnabled, cameraDataTop.hdrColorBufferPrecision, true); //make sure format has Alpha channel
            m_CameraUIRT = new RenderTexture(descTop);
            m_CameraUIRT.name = k_CameraUIRTName;
            
            // Use the RenderTexture as camera target
            // can't do cameraDataTop.targetTexture because the rendered content does not preserve alpha
            cameraUI.targetTexture = m_CameraUIRT;
        }
        
        // Bind resources and values to material
        Shader.SetGlobalTexture(k_CameraUIRTName, m_CameraUIRT);
        Shader.SetGlobalInt(k_EnabledName, workaroundIsEnabled? 1:0);
        
        // Init pass and send resources to it
        if (m_Pass == null)
        {
            m_Pass = new CameraColorSpaceWorkaroundPass(material);
        }
        
        // Add callback injection
        RenderPipelineManager.beginCameraRendering += OnBeginCamera;
    }

    private void Cleanup()
    {
        // Remove callback injection
        RenderPipelineManager.beginCameraRendering -= OnBeginCamera;
        
        // Cleanup texture
        if (m_CameraUIRT != null)
        {
            m_CameraUIRT.DiscardContents();
            m_CameraUIRT.Release();
        }
        
        // Reset UI camera settings
        if (cameraUI != null)
        {
            cameraUI.targetTexture = null;
            if(m_CameraUIAddData == null) m_CameraUIAddData = cameraUI.GetUniversalAdditionalCameraData();
            cameraUI.depth = camera3D.depth + 1;
            m_CameraUIAddData.renderType = CameraRenderType.Overlay;
        }
    }
    
    private void OnBeginCamera(ScriptableRenderContext context, Camera cam)
    {
        if (cam.Equals(camera3D))
        {
            // Enqueue pass for the 3D camera
            m_Pass.renderPassEvent = blendEvent;
            cam.GetUniversalAdditionalCameraData().scriptableRenderer.EnqueuePass(m_Pass);
        }
    }
}

// Show a warning box if workaroundIsEnabled is false 
#if UNITY_EDITOR
[CustomEditor(typeof(CameraColorSpaceWorkaround))]
class CameraColorSpaceWorkaroundEditor : Editor
{
    private const string k_MessageDisabled =
        "'Workaround Is Enabled' checkbox is disabled. The extra pass will still run, but just doing normal blending, which affects performance. \n"+
        "Therefore only use this for debugging. You can stop the extra pass from running by disabling on the component header or remove this component.";

    private const string k_MessageEnabled =
        "'Workaround Is Enabled' checkbox is enabled. The workaround pass is injected and the shader will run with color space conversion path, depending on active color space. \n" +
        "i.e. If project is in Linear color space, the UI will blend in Gamma color space and vice versa. \n" +
        "Please note that this workaround is only suitable for UI with ALL objects using alpha blending.";

    public override void OnInspectorGUI()
    {
        base.OnInspectorGUI();
        
        CameraColorSpaceWorkaround obj = (CameraColorSpaceWorkaround)target;
        if (!obj.workaroundIsEnabled)
        {
            EditorGUILayout.HelpBox(k_MessageDisabled, MessageType.Warning);
        }
        else
        {
            EditorGUILayout.HelpBox(k_MessageEnabled, MessageType.Info);
        }
    }
}
#endif

// A blit pass that blends the 2 camera contents
public class CameraColorSpaceWorkaroundPass : ScriptableRenderPass
{
    private ProfilingSampler m_ProfilingSampler = new ("CameraColorSpaceWorkaroundPass");
    private RTHandle m_CameraHandle; //BufferA
    private RTHandle m_TargetHandle; //BufferB
    private Material m_Material;

    public CameraColorSpaceWorkaroundPass(Material mat)
    {
        m_Material = mat;
    }
    
    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
    {
        CommandBuffer cmd = CommandBufferPool.Get();
        
        // Find out the source and destination for the blit operation
        var universalRenderer = (UniversalRenderer)renderingData.cameraData.renderer;
        var currentTarget = renderingData.cameraData.renderer.cameraColorTargetHandle;
        var bufferA = universalRenderer.m_ColorBufferSystem.GetBufferA(); //BufferA
        var bufferB = universalRenderer.m_ColorBufferSystem.GetFrontBuffer(cmd); //BufferB
        if (currentTarget == bufferA)
        {
            m_CameraHandle = bufferA;
            m_TargetHandle = bufferB;
        }
        else
        {
            // When post-processing is enabled on 3D camera, post-processing is rendered into buffer B
            m_CameraHandle = currentTarget; // Can't be B as target is neither B nor A for some reason
            m_TargetHandle = bufferA;
        }
        
        // Blit from "A" into "B" as we can't Blit from-to the same texture
        using (new ProfilingScope(cmd, m_ProfilingSampler))
        {
            Blitter.BlitCameraTexture(cmd, m_CameraHandle, m_TargetHandle, m_Material, 0);
        }
        
        // Use "B" as the camera target so that we don't need another blit from "B" back to "A"
        universalRenderer.SwapColorBuffer(cmd);
        
        context.ExecuteCommandBuffer(cmd);
        cmd.Clear();
        CommandBufferPool.Release(cmd);
    }
}

// Wrapper so that we can use the private static function
namespace UnityEngine.Rendering.Universal
{
    public sealed partial class UniversalRenderPipeline
    {
        public static void InitializeCameraDataWrapper(Camera camera,
            UniversalAdditionalCameraData additionalCameraData, bool resolveFinalTarget, out CameraData cameraData)
        {
            InitializeCameraData(camera, additionalCameraData, resolveFinalTarget, out cameraData);
        }
    }
}