#ifndef HOJAVERDE_BLUR
#define HOJAVERDE_BLUR

#define MI_PI 3.14159265359
#define MI_E 2.71828182846

#define SAMPLES 30

float4 GaussianBlurV(sampler2D tex, float2 uv, float size, float standardDeviation)
{
    float sum = 0.0;
    float4 col = 0;

    for (float index = 0; index < SAMPLES; index ++)
    {
        float offset = (index / (SAMPLES - 1) - 0.5) * size;

        float2 blurUv = uv + float2(0, offset);

        float stDevSquared = standardDeviation * standardDeviation;
        float gauss = (1 / sqrt(2 * MI_PI * stDevSquared)) * pow(MI_E, - ((offset * offset) / (2 * stDevSquared)));

        sum += gauss;
        col += tex2D(tex, blurUv) * gauss;
    }

    return col / sum;
}

float4 GaussianBlurH(sampler2D tex, float2 uv, float size, float standardDeviation)
{
    float sum = 0.0;
    float4 col = 0;
    float invAspect = _ScreenParams.y / _ScreenParams.x;

    for (float index = 0; index < SAMPLES; index ++)
    {
        float offset = (index / (SAMPLES - 1) - 0.5) * invAspect * size;

        float2 blurUv = uv + float2(offset, 0);

        float stDevSquared = standardDeviation * standardDeviation;
        float gauss = (1 / sqrt(2 * MI_PI * stDevSquared)) * pow(MI_E, - ((offset * offset) / (2 * stDevSquared)));

        sum += gauss;
        col += tex2D(tex, blurUv) * gauss;
    }

    return col / sum;
}
#endif
