using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class DynamicFoamRenderFeature : ScriptableRendererFeature
{
    class CustomRenderPass : ScriptableRenderPass
    {
        public Settings settings;

        private readonly ShaderTagId _depthPassId = new ShaderTagId("DepthDifference");
        private static readonly int DepthDifferencePropertyId = Shader.PropertyToID("DepthDifference");
        private readonly int DynamicFoamPropertyId = Shader.PropertyToID("DynamicFoam");

        private static readonly RenderTargetIdentifier DepthDifferenceRtId =
            new RenderTargetIdentifier(DepthDifferencePropertyId);

        private RenderTexture _foamWrite;
        private RenderTexture _foamRead;

        private RenderTargetHandle tempTextureHandle;
        private RenderTargetHandle temp2TextureHandle;


        private void CreateFoamRenderTextures(RenderTextureDescriptor cameraTextureDescriptor)
        {
            _foamWrite = new RenderTexture(cameraTextureDescriptor.width, cameraTextureDescriptor.height, 0,
                RenderTextureFormat.RFloat);
            _foamWrite.wrapMode = TextureWrapMode.Clamp;
            _foamWrite.filterMode = FilterMode.Bilinear;

            _foamRead = new RenderTexture(cameraTextureDescriptor.width, cameraTextureDescriptor.height, 0,
                RenderTextureFormat.RFloat);
            _foamRead.wrapMode = TextureWrapMode.Clamp;
            _foamRead.filterMode = FilterMode.Bilinear;

            _foamRead.enableRandomWrite = true;
            _foamWrite.enableRandomWrite = true;

            tempTextureHandle.Init("_TempBlitMatTex");
            temp2TextureHandle.Init("_Temp2BlitMatTex");
        }

        public void ReleaseRenderTextures()
        {
            _foamRead.Release();
            _foamWrite.Release();

            _foamRead = null;
            _foamWrite = null;
        }

        public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)
        {
            if (_foamWrite == null)
                CreateFoamRenderTextures(cameraTextureDescriptor);

            cmd.GetTemporaryRT(DepthDifferencePropertyId, cameraTextureDescriptor);
            ConfigureTarget(DepthDifferenceRtId);
            ConfigureClear(ClearFlag.All, Color.black);
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            if (settings?.foamFlowCompute == null)
                return;

            var cmd = CommandBufferPool.Get("DynamicFoam");

            var drawSettings =
                CreateDrawingSettings(_depthPassId, ref renderingData, SortingCriteria.CommonOpaque);

            var filterSettings = new FilteringSettings(RenderQueueRange.all);
            context.DrawRenderers(renderingData.cullResults, ref drawSettings, ref filterSettings);

            var flowKernel = settings.foamFlowCompute.FindKernel("FoamFlowKernel");
            settings.foamFlowCompute.SetTexture(flowKernel, "_DepthFoam_Write", _foamWrite);
            settings.foamFlowCompute.SetTexture(flowKernel, "_DepthFoam_Read", _foamRead);

            cmd.SetComputeTextureParam(settings.foamFlowCompute, flowKernel, DepthDifferencePropertyId,
                DepthDifferenceRtId);

            settings.foamFlowCompute.GetKernelThreadGroupSizes(flowKernel, out var xThreadGroups,
                out var yThreadGroups, out _);

            cmd.SetComputeFloatParam(settings.foamFlowCompute, "flowSpeed",settings.flowSpeed);
            cmd.SetComputeFloatParam(settings.foamFlowCompute, "persistence",settings.persistence);
            cmd.SetComputeVectorParam(settings.foamFlowCompute, "flowDirection",settings.flowDirection);

            var xgroups = Mathf.CeilToInt(_foamRead.width / (float) xThreadGroups);
            var ygroups = Mathf.CeilToInt(_foamRead.height / (float) yThreadGroups);
            cmd.DispatchCompute(settings.foamFlowCompute, flowKernel, xgroups, ygroups, 1);


            if (settings.blurMaterial != null)
            {
                cmd.GetTemporaryRT(tempTextureHandle.id, renderingData.cameraData.cameraTargetDescriptor,
                    FilterMode.Bilinear);
                cmd.GetTemporaryRT(temp2TextureHandle.id, renderingData.cameraData.cameraTargetDescriptor,
                    FilterMode.Bilinear);

                Blit(cmd, _foamWrite, tempTextureHandle.Identifier(), settings.blurMaterial, 0);
                Blit(cmd, tempTextureHandle.Identifier(), temp2TextureHandle.Identifier(), settings.blurMaterial, 1);
                Blit(cmd, temp2TextureHandle.Identifier(), _foamWrite);
            }

            cmd.SetGlobalTexture(DynamicFoamPropertyId, _foamWrite);

            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }

        public override void FrameCleanup(CommandBuffer cmd)
        {
            cmd.ReleaseTemporaryRT(DepthDifferencePropertyId);
            cmd.ReleaseTemporaryRT(tempTextureHandle.id);
            cmd.ReleaseTemporaryRT(temp2TextureHandle.id);

            SwapFoamTextures();
        }

        private void SwapFoamTextures()
        {
            (_foamRead, _foamWrite) = (_foamWrite, _foamRead);
        }
    }

    CustomRenderPass _scriptablePass;

    public override void Create()
    {
        _scriptablePass = new CustomRenderPass
        {
            renderPassEvent = RenderPassEvent.BeforeRenderingOpaques,
            settings = settings
        };
    }

    private void OnDisable()
    {
        _scriptablePass.ReleaseRenderTextures();
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        renderer.EnqueuePass(_scriptablePass);
    }

    public Settings settings;

    [Serializable]
    public class Settings
    {
        public float persistence = 0.95f;
        public float flowSpeed = 0.01f;
        public Vector2 flowDirection = Vector2.right;
        public ComputeShader foamFlowCompute;
        public Material blurMaterial;
    }
}