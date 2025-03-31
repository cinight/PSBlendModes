Shader "Hidden/CameraColorSpaceWorkaround"
{
    Properties
    {
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline" = "UniversalPipeline"}
        ZWrite Off Cull Off ZTest Always
        
        Pass
        {
            Name "CameraColorSpaceWorkaroundPass"

            HLSLPROGRAM
            
            #pragma vertex Vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"
            
            TEXTURE2D_X(_CameraUIRT);
            int _CameraColorSpaceWorkaroundEnabled;
            
            float4 frag (Varyings i) : SV_Target
            {
                float4 camUI = SAMPLE_TEXTURE2D(_CameraUIRT, sampler_LinearClamp, i.texcoord);
                float4 cam3D = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, i.texcoord);
                
                float4 result = cam3D;

                // undo premultiplied alpha due to UI
                // rendered to black background with default UI shader
                camUI.rgb /= (camUI.a+0.001);

                if(_CameraColorSpaceWorkaroundEnabled)
                {
                    // Gamma project, Linear UI
                    #if UNITY_COLORSPACE_GAMMA
                        camUI.rgb = SRGBToLinear(camUI.rgb);
                        cam3D.rgb = SRGBToLinear(cam3D.rgb);
                        result.rgb = lerp(cam3D.rgb, camUI.rgb, camUI.a);
                        result.rgb = LinearToSRGB(result.rgb);
                    
                    // Linear project, Gamma UI
                    #else
                        camUI.rgb = LinearToSRGB(camUI.rgb);
                        cam3D.rgb = LinearToSRGB(cam3D.rgb);
                        result.rgb = lerp(cam3D.rgb, camUI.rgb, camUI.a);
                        result.rgb = SRGBToLinear(result.rgb);

                    #endif
                }
                else
                {
                    result.rgb = lerp(cam3D.rgb, camUI.rgb, camUI.a);
                }

                return result;
            }
            
            ENDHLSL
        }

    }
    CustomEditor "CustomShaderGUI"
}