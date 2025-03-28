Shader "Test/Transparent"
{
	Properties
	{
		_Color ("Color", Color) = (0, 0.5, 1, 1)
		[Enum(UnityEngine.Rendering.BlendMode)] _SrcBlend("_SrcFactor", Int) = 1.0
		[Enum(UnityEngine.Rendering.BlendMode)] _DstBlend("_DstFactor", Int) = 10.0
        //[Enum(UnityEngine.Rendering.BlendMode)] _SrcBlendAlpha("_SrcBlendAlpha", Float) = 1.0
        //[Enum(UnityEngine.Rendering.BlendMode)] _DstBlendAlpha("_DstBlendAlpha", Float) = 0.0
        [Toggle] _PremultiplyAlpha("Premultiply Alpha", Float) = 1
	}
	SubShader
	{
		Tags { "RenderType"="Transparent" "RenderPipeline" = "UniversalPipeline" }

		Pass
		{
			Tags { "LightMode" = "UniversalForward" }
			
			Blend [_SrcBlend] [_DstBlend]//, [_SrcBlendAlpha] [_DstBlendAlpha]
			Zwrite Off

			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			
			struct appdata
			{
				float4 positionOS : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float4 positionCS : SV_POSITION;
				float2 uv : TEXCOORD0;
			};
			
			v2f vert (appdata v)
			{
				v2f o;
				o.positionCS = TransformObjectToHClip(v.positionOS.xyz);
				o.uv = v.uv;
				
				return o;
			}

			float4 _Color;
			uint _PremultiplyAlpha;
			
			float4 frag (v2f i) : SV_Target
			{
				float3 color = float3(0,0.5,1.0);
				float alpha = 1-i.uv.x;
				
                if(_PremultiplyAlpha == 1)
                {
                    color.rgb *= alpha;
                }
				
				float4 result = float4(color, alpha);
				return result;
			}
			ENDHLSL
		}
	}
}