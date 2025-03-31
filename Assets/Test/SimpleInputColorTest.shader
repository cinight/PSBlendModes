Shader "Test/SimpleInputColorTest"
{
    Properties
    {
        _Vector ("Vector", Vector) = (0, 0.5, 1, 1)
        _Color ("Color", Color) = (0, 0.5, 1, 1)
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

            float4 _Color;
            float4 _Vector;

            float4 frag (v2f i) : SV_Target
            {
                if(i.uv.x < 0.5)
                {
					/* The color value we see on the color picker is in sRGB,
                	and the color picker does the conversion automatically for us.
                	So for this raw Vector4 value we need to convert the value back
                	to linear space manually */
					#if UNITY_COLORSPACE_GAMMA
					#else
						_Vector.rgb = SRGBToLinear(_Vector.rgb);
					#endif
                	
                    return _Vector;
                }

            	return _Color;

            }
            ENDHLSL
        }
    }
}
