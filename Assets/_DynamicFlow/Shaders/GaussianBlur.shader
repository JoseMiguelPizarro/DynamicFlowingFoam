Shader "GaussianBlur"
{
    Properties
    {
        _Size ("Radius", float) = 0.1
        _StandardDeviation ("StandardDeviation", float) = 0.1
       [HideInInspector] _MainTex ("Main Tex", 2D) = "white" { }
    }
    
    SubShader
    {
        Tags { "RenderPipeline" = "UniversalPipeline" }
        Cull Back
        
        HLSLINCLUDE
        #pragma target 3.5
        ENDHLSL
        
        //Vertical Blur
        Pass
        {
            ZWrite Off
            ZTest Always
            
            HLSLPROGRAM
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Blur.hlsl"
            
            CBUFFER_START(UnityPerMaterial)
            float _Size;
            float _StandardDeviation;
            CBUFFER_END
            
            sampler2D _MainTex;
            float _Blur;
            
            #pragma vertex vert
            #pragma fragment frag
            
            struct Attributes
            {
                float4 positionOS: POSITION;
                float4 uv: TEXCOORD;
            };
            
            struct Varyings
            {
                float4 positionCS: SV_POSITION;
                float4 uv: TEXCOORD;
            };
            
            Varyings vert(Attributes i)
            {
                Varyings o;
                o.positionCS = TransformObjectToHClip(i.positionOS.xyz);
                o.uv = i.uv;
                return o;
            }
            
            float4 frag(Varyings i): SV_TARGET
            {
                float4 blurredColor = GaussianBlurV(_MainTex, i.uv, _Size, _StandardDeviation);
                return blurredColor;
            }
            ENDHLSL
        }
        
        //HORIZONTAL
        Pass
        {
            Name "Forward"
            
            ZWrite Off
            ZTest Always
            
            HLSLPROGRAM
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Blur.hlsl"
            
            CBUFFER_START(UnityPerMaterial)
            float _Size;
            float _StandardDeviation;
            CBUFFER_END
            
            sampler2D _MainTex;
            float _Blur;
            
            #pragma vertex vert
            #pragma fragment frag
            
            struct Attributes
            {
                float4 positionOS: POSITION;
                float4 uv: TEXCOORD;
            };
            
            struct Varyings
            {
                float4 positionCS: SV_POSITION;
                float4 uv: TEXCOORD;
            };
            
            Varyings vert(Attributes i)
            {
                Varyings o;
                o.positionCS = TransformObjectToHClip(i.positionOS.xyz);
                o.uv = i.uv;
                return o;
            }
            
            float4 frag(Varyings i): SV_TARGET
            {
                float4 blurredColor = GaussianBlurH(_MainTex, i.uv, _Size, _StandardDeviation);
                return blurredColor;
            }
            ENDHLSL
        }
    }
}