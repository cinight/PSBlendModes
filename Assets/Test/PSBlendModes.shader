Shader "Test/PSBlendModes"
{
	Properties
	{
		[Enum(Normal,1,LinearDodge,2,Screen,3,Multiply,4)] _BlendMode ("Blend mode", Float) = 1
		_ColorTop ("Color top", Color) = (0, 0.5, 1, 1)
		_ColorBottom ("Color bottom", Color) = (0.5, 0.5, 0.5, 1)
	}
	SubShader
	{
		Tags { "RenderType"="Opaque" "RenderPipeline" = "UniversalPipeline" }

		Pass
		{
			Tags { "LightMode" = "UniversalForward" }

			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
			
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
			
			float _BlendMode;
			float4 _ColorTop;
			float4 _ColorBottom;

			float3 AlphaBlending(float3 top, float3 bottom, float a)
			{
				bottom = saturate(bottom);
				top = saturate(top);
				a = saturate(a);
				
				float3 result = lerp(bottom, top, a);
				
				return result;
			}
			
			float4 frag (v2f i) : SV_Target
			{
				// Base
				float4 result = 1;
				float3 colorTop = _ColorTop.rgb;
				float3 colorBottom = _ColorBottom.rgb;
				float alpha = i.uv.x;
				
				// Blending - Normal
				if(_BlendMode == 1)
				{
					result.rgb = AlphaBlending(colorBottom, colorTop, alpha);
				}

				// Blending - Linear Dodge (Add)
				if(_BlendMode == 2)
				{
					float3 colorBottomLin = colorBottom;
					float3 colorTopLin = colorTop;
					
					// Fix color space
					#if UNITY_COLORSPACE_GAMMA
					#else
						colorBottomLin = LinearToSRGB(colorBottomLin);
						colorTopLin = LinearToSRGB(colorTopLin);
					#endif
					
					float3 colorLin = colorBottomLin + colorTopLin;

					// Fix color space
					#if UNITY_COLORSPACE_GAMMA
					#else
						colorLin = SRGBToLinear(colorLin);
					#endif

					result.rgb = AlphaBlending(colorBottom, colorLin, alpha);
				}

				// Blending - Screen
				if(_BlendMode == 3)
				{
					float3 colorBottomLin = colorBottom;
					float3 colorTopLin = colorTop;
					
					// Fix color space
					#if UNITY_COLORSPACE_GAMMA
					#else
						colorBottomLin = LinearToSRGB(colorBottomLin);
						colorTopLin = LinearToSRGB(colorTopLin);
					#endif
					
					float3 colorLin = colorTopLin * (1-colorBottomLin) + colorBottomLin;

					// Fix color space
					#if UNITY_COLORSPACE_GAMMA
					#else
						colorLin = SRGBToLinear(colorLin);
					#endif
					
					result.rgb = AlphaBlending(colorBottom, colorLin, alpha);
				}

				// Blending - Multiply
				if(_BlendMode == 4)
				{
					float3 color = colorBottom * colorTop;
					result.rgb = AlphaBlending(colorBottom, color, alpha);
				}
				
				// Output
				return result;
			}
			ENDHLSL
		}
	}
}