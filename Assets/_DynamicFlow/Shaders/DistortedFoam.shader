Shader "DynamicFoam"
{
    Properties
    {
        _DistortionMap("Distortion Map",2d) = "white" {}
        _DistortionStrength("Distortion strength",float) = 0.01
    }

    SubShader
    {
        Tags
        {
            "RenderType"="Transparent"
            "Queue"="Transparent"
        }

        Pass
        {
            HLSLPROGRAM
            #define REQUIRE_DEPTH_TEXTURE 1
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv:TEXCOORD1;
            };


            float _DistortionStrength;
            sampler2D DynamicFoam;

            sampler2D _DistortionMap;

            Varyings vert(Attributes v)
            {
                Varyings o;
                float4 positionCS = TransformObjectToHClip(v.positionOS.xyz);
                o.uv = v.uv;

                o.positionCS = positionCS;
                return o;
            }

            float4 frag(Varyings i) : SV_Target
            {
                float2 distortion = tex2D(_DistortionMap, i.uv + float2(-_Time.y, 0)).xy * _DistortionStrength;
                float4 foam = tex2D(DynamicFoam, i.uv + distortion);
                return foam.xxxx;
            }
            ENDHLSL
        }

        pass
        {
            Tags
            {
                "LightMode"="DepthDifference"
            }
            HLSLPROGRAM
            #define REQUIRE_DEPTH_TEXTURE 1
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

            #pragma vertex vert
            #pragma fragment frag

            struct Attributes
            {
                float4 positionOS:POSITION;
                float2 uv:TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionCS:SV_POSITION;
                float2 uv:TEXCOORD0;
                float4 screenPosition:TEXCOORD1;
            };

            Varyings vert(Attributes input)
            {
                Varyings output;
                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                output.screenPosition = ComputeScreenPos(output.positionCS);
                output.uv = input.uv;

                float2 uv = input.uv;
                uv.y = 1 - uv.y;
                uv = (uv - 0.5) * 2;

                output.positionCS = float4(uv, 0, 1);

                return output;
            }

            float4 frag(Varyings input): SV_Target
            {
                float4 screenPosNorm = input.screenPosition / input.screenPosition.w;
                float depth = LinearEyeDepth(SampleSceneDepth(screenPosNorm.xy), _ZBufferParams);
                float depthDifference = abs(depth - LinearEyeDepth(screenPosNorm.z, _ZBufferParams));

                return 1 - depthDifference;
            }
            ENDHLSL
        }
    }
}