Shader "Custom/Dissolve"
{
    Properties
    {
        _Color ("Color", Color) = (1,1,1,1)
        _MainTex ("Albedo (RGB)", 2D) = "white" {}

        _NormalMap ("Normal Map", 2D) = "bump" {}

        _OcclusionMap ("Occlusion Map", 2D) = "bump" {}
        _Occlusion("Occlusion", Range(0, 1)) = 1
        _OcclusionDarkWeight("Occlusion Dark Weight", Range(0, 1)) = 1

        _Glossiness ("Smoothness", Range(0,1)) = 0.5

        _Metallic ("Metallic", Range(0,1)) = 0.0

        _CoarseNoiseFrequency ("Coarse Noise Frequency", float) = 1.0
        _FineNoiseFrequency ("Fine Noise Frequency", float) = 1.0
        _FineNoiseOctave ("Fine Noise Octave", float) = 1.0
        

        _DissolveAmount("Dissolve Amount", Range(0.0, 1.0)) = 0.0 // 1: no dissolve 0: full dissolve
        _EdgeWidth("Edge Width", Range(0.0, 1.0)) = 0.0
        _EdgeColor("Edge Color", Color) = (1,0,0,0)

        _Emission("Emission", float) = 0
        _EmissionEdgeRatio("Emission Edge Ratio", Range(0.0, 1.0)) = 0.5
        _EmissionFlicherSpeed ("Emission Flicker Speed", Range(0.1, 10.0)) = 1.0
        [HDR] _EmissionColor("Emmision Color", Color) = (1,1,1,1)

        _ToggleInner("Show Inner", int) = 0
        _ToggleOuter("Show Outer", int) = 0
        _ToggleEdge("Show Edge", int) = 1
        _ToggleFull("Show Full", int) = 0
    }
    SubShader
    {
        Tags { "RenderType"="Transparent"
        "Queue"="Transparent" }
        LOD 200

        Cull back
        Blend One One
        ZWrite On
        ZTest LEqual

        CGPROGRAM
        // Physically based Standard lighting model, and enable shadows on all light types
        #pragma surface surf Standard fullforwardshadows alpha:blend

        // Use shader model 3.0 target, to get nicer looking lighting
        #pragma target 3.0

        sampler2D _MainTex;
        sampler2D _NormalMap;
        sampler2D _OcclusionMap;

        struct Input
        {
            float2 uv_MainTex;
            float2 uv_NormalMap;
            float2 uv_OcclusionMap;
            float3 worldPos;
        };

        half _Glossiness;
        half _Metallic;

        fixed4 _Color;

        float _CoarseNoiseFrequency;
        float _FineNoiseFrequency;
        float _FineNoiseOctave;
        float _EmissionFlicherSpeed;

        float _Emission;
        float _EmissionEdgeRatio;
        float4 _EmissionColor;

        float _Occlusion;
        float _OcclusionDarkWeight;

        float _DissolveAmount;
        float _EdgeWidth;
        fixed4 _EdgeColor;

        int _ToggleInner;
        int _ToggleOuter;
        int _ToggleEdge;
        int _ToggleFull;

        // Add instancing support for this shader. You need to check 'Enable Instancing' on materials that use the shader.
        // See https://docs.unity3d.com/Manual/GPUInstancing.html for more information about instancing.
        // #pragma instancing_options assumeuniformscaling
        UNITY_INSTANCING_BUFFER_START(Props)
            // put more per-instance properties here
        UNITY_INSTANCING_BUFFER_END(Props)

        float2 noise2d1d(float2 uv) {
            float2 ret = frac(sin(dot(uv, float2(12.9898, 78.233))) * 43758.5453);
            return ret;
        }

        float2 noise2d2d(float2 uv) {
            float2 ret = float2(frac(sin(dot(uv, float2(12.9898, 78.233))) * 43758.5453),
                frac(cos(dot(uv, float2(12.9898, 78.233))) * 43758.5453));

            ret = ret * 2 - 1.0; // from 0~1 to -1~1
            ret = normalize(ret);
            return ret;
        }

        float noise3d1d(float3 xyz) {
            return frac(sin(dot(xyz, float3(12.9898, 78.233, 37.719))) * 43758.5453);
        }

        float noise3d3d(float3 xyz) {
            float3 ret = float3(
                frac(sin(dot(xyz, float3(12.9898, 78.233, 45.543))) * 43758.5453),
                frac(sin(dot(xyz, float3(54.123, 43.543, 32.989))) * 43758.5453),
                frac(sin(dot(xyz, float3(93.989, 43.242, 65.654))) * 43758.5453)
            );

            ret = ret * 2 - 1.0; // from 0~1 to -1~1
            ret = normalize(ret);
            return ret;
        }

        float noise1d(float3 xyz) {
            return frac(sin(dot(xyz, float3(12.9898, 78.233, 37.719))) * 43758.5453);
        }

        // Value Noise
        float valueNoise2d(float2 fraction) {
            int power = 3;
            float frac_x = fraction.x;
            float frac_y = fraction.y;
            float ein, eout, intp;

            float lx = floor(fraction.x);
            float rx = ceil(fraction.x);
            float ly = floor(fraction.y);
            float uy = ceil(fraction.y);

            // Get noise for four corners
            float valLowerLeft = noise2d1d(float2(lx, ly));
            float valLowerRight = noise2d1d(float2(rx, ly));
            float valUpperLeft = noise2d1d(float2(lx, uy));
            float valUpperRight = noise2d1d(float2(rx, uy));

            // Interpolate horizontally
            ein = pow(frac(frac_x), power);
            eout = pow(frac(frac_x)-1, power)+1;
            intp = lerp(ein, eout, frac(frac_x));
            float intp_val_lower = lerp(valLowerLeft, valLowerRight, intp);
            float intp_val_upper = lerp(valUpperLeft, valUpperRight, intp);

            // Interpolate vertically
            ein = pow(frac(frac_y), power);
            eout = pow(frac(frac_y)-1, power)+1;
            intp = lerp(ein, eout, frac(frac_y));
            float intp_val = lerp(intp_val_lower, intp_val_upper, intp);

            return intp_val;
        }

        float valueNoise3d(float3 fraction) {
            int power = 3;
            float frac_x = fraction.x;
            float frac_y = fraction.y;
            float frac_z = fraction.z;
            float ein, eout, intp;

            float x1 = floor(fraction.x);
            float x2 = ceil(fraction.x);
            float y1 = floor(fraction.y);
            float y2 = ceil(fraction.y);
            float z1 = floor(fraction.z); // lower z
            float z2 = ceil(fraction.z); // upper z


            // Get noise for eight corners
            float x1y1z1 = noise3d1d(float3(x1, y1, z1));
            float x1y2z1 = noise3d1d(float3(x1, y2, z1));
            float x1y1z2 = noise3d1d(float3(x1, y1, z2));
            float x1y2z2 = noise3d1d(float3(x1, y2, z2));
            float x2y1z1 = noise3d1d(float3(x2, y1, z1));
            float x2y2z1 = noise3d1d(float3(x2, y2, z1));
            float x2y1z2 = noise3d1d(float3(x2, y1, z2));
            float x2y2z2 = noise3d1d(float3(x2, y2, z2));

            // Reduce X dim
            ein = pow(frac(frac_x), power);
            eout = pow(frac(frac_x)-1, power)+1;
            intp = lerp(ein, eout, frac(frac_x));
            float y1z1 = lerp(x1y1z1, x2y1z1, intp);
            float y1z2 = lerp(x1y1z2, x2y1z2, intp);
            float y2z1 = lerp(x1y2z1, x2y2z1, intp);
            float y2z2 = lerp(x1y2z2, x2y2z2, intp);

            // Reduce y
            ein = pow(frac(frac_y), power);
            eout = pow(frac(frac_y)-1, power)+1;
            intp = lerp(ein, eout, frac(frac_y));
            float _z1 = lerp(y1z1, y2z1, intp);
            float _z2 = lerp(y1z2, y2z2, intp);

            // Reduce z
            ein = pow(frac(frac_z), power);
            eout = pow(frac(frac_z)-1, power)+1;
            intp = lerp(ein, eout, frac(frac_z));
            float intp_val = lerp(_z1, _z2, intp);

            return intp_val;
        }

        float4 paintValueNoise2d(float2 vertex_world) {

            float2 fraction = vertex_world * _FineNoiseFrequency * pow(2, _FineNoiseOctave);
            float noise = valueNoise2d(fraction);
            return half4(noise, noise, noise, 1);
        }

        float4 paintValueNoise3d(float3 vertex_world) {

            float3 fraction = vertex_world * _FineNoiseFrequency * pow(2, _FineNoiseOctave);
            float noise = valueNoise3d(fraction);
            return half4(noise, noise, noise, 1);
        }
        
        // Perlin Noise
        float gradientDot2d(float2 gradient_xy, float2 xy) {
            float2 gradient = noise2d2d(gradient_xy);
            float2 offset = xy - gradient_xy;
            return dot(gradient, offset);
        }

        float gradientDot3d(float3 gradient_xyz, float3 xyz) {
            float3 gradient = noise3d3d(gradient_xyz);
            float3 offset = xyz - gradient_xyz;
            return dot(gradient, offset);
        }

        float perlinNoise2d(float2 fraction) {
            float frac_x = fraction.x;
            float frac_y = fraction.y;
            float ein, eout, intp;

            float x1 = floor(fraction.x);
            float x2 = ceil(fraction.x);
            float y1 = floor(fraction.y);
            float y2 = ceil(fraction.y);

            // 1. Dot product of random gradient on four corners
            float x1y1 = gradientDot2d(float2(x1, y1), fraction);
            float x1y2 = gradientDot2d(float2(x1, y2), fraction);
            float x2y1 = gradientDot2d(float2(x2, y1), fraction);
            float x2y2 = gradientDot2d(float2(x2, y2), fraction);

            // Lerp x
            ein = frac(frac_x);
            ein = 6 * pow(ein, 5) - 15 * pow(ein, 4) + 10 * pow(ein, 3);
            float _y1 = lerp(x1y1, x2y1, ein);
            float _y2 = lerp(x1y2, x2y2, ein);

            // Lerp y
            ein = frac(frac_y);
            ein = 6 * pow(ein, 5) - 15 * pow(ein, 4) + 10 * pow(ein, 3);
            float ret = lerp(_y1, _y2, ein);

            return ret * 0.5 + 0.5;
        }

        float4 paintPerlinNoise2d(float2 vertex_world) {

            float2 fraction = vertex_world * _CoarseNoiseFrequency;
            float noise = perlinNoise2d(fraction);
            return half4(noise, noise, noise, 1);
        }

        float perlinNoise3d(float3 fraction) {
            float frac_x = fraction.x;
            float frac_y = fraction.y;
            float frac_z = fraction.z;
            float ein, eout, intp;

            float x1 = floor(fraction.x);
            float x2 = ceil(fraction.x);
            float y1 = floor(fraction.y);
            float y2 = ceil(fraction.y);
            float z1 = floor(fraction.z);
            float z2 = ceil(fraction.z);

            // 1. Dot product of random gradient on four corners
            float x1y1z1 = gradientDot3d(float3(x1, y1, z1), fraction);
            float x1y1z2 = gradientDot3d(float3(x1, y1, z2), fraction);
            float x1y2z1 = gradientDot3d(float3(x1, y2, z1), fraction);
            float x1y2z2 = gradientDot3d(float3(x1, y2, z2), fraction);
            float x2y1z1 = gradientDot3d(float3(x2, y1, z1), fraction);
            float x2y1z2 = gradientDot3d(float3(x2, y1, z2), fraction);
            float x2y2z1 = gradientDot3d(float3(x2, y2, z1), fraction);
            float x2y2z2 = gradientDot3d(float3(x2, y2, z2), fraction);

            // Lerp x
            ein = frac(frac_x);
            ein = 6 * pow(ein, 5) - 15 * pow(ein, 4) + 10 * pow(ein, 3);
            float y1z1 = lerp(x1y1z1, x2y1z1, ein);
            float y1z2 = lerp(x1y1z2, x2y1z2, ein);
            float y2z1 = lerp(x1y2z1, x2y2z1, ein);
            float y2z2 = lerp(x1y2z2, x2y2z2, ein);

            // Lerp y
            ein = frac(frac_y);
            ein = 6 * pow(ein, 5) - 15 * pow(ein, 4) + 10 * pow(ein, 3);
            float _z1 = lerp(y1z1, y2z1, ein);
            float _z2 = lerp(y1z2, y2z2, ein);

            // Lerp y
            ein = frac(frac_z);
            ein = 6 * pow(ein, 5) - 15 * pow(ein, 4) + 10 * pow(ein, 3);
            float ret = lerp(_z1, _z2, ein);

            return ret * 0.5 + 0.5;
        }

        float4 paintPerlinNoise3d(float3 vertex_world) {
            float3 fraction = vertex_world * _CoarseNoiseFrequency;
            float noise = perlinNoise3d(fraction);
            return half4(noise, noise, noise, 1);
        }

        void surf (Input IN, inout SurfaceOutputStandard o)
        {

            fixed4 c = tex2D (_MainTex, IN.uv_MainTex) * _Color;
            c.a = 1.0;

            float4 noise = paintPerlinNoise2d(IN.uv_MainTex);
            noise = noise * paintValueNoise2d(IN.uv_MainTex);
            float4 emmision_factor = paintValueNoise2d(IN.uv_MainTex * _Time.x * _EmissionFlicherSpeed) * 2;

            /*
            inner == 1 : texture
            inner xor outer : edge
            outer == 1 : Dissolved area. Show background
            */
            float3 inner = step(noise.rgb, (1 - _DissolveAmount) - _EdgeWidth);
            float3 inner_emission = step(noise.rgb, (1 - _DissolveAmount) - _EdgeWidth * _EmissionEdgeRatio);
            float3 outer = step(noise.rgb, (1 - _DissolveAmount) + 0);

            float3 edge = (outer - inner) * _EdgeColor; // 1 if it is in edge
            float3 edge_emission = (outer - inner_emission) * _EdgeColor; // 1 if it is in edge
            
            if (_ToggleInner)
                o.Albedo = inner;
            else if (_ToggleOuter)
                o.Albedo = outer;
            else if (_ToggleEdge) {
                o.Albedo = float3(edge.x, edge.y, edge.z);
            }
            else if (_ToggleFull) {
                if (edge.x) {
                    c.rgb = edge;
                    if (edge_emission.x) {
                        o.Emission = _EmissionColor.rgb * _Emission * emmision_factor;
                    }              
                }
                o.Albedo = c * (outer.x);
                o.Alpha = c.a * (outer.x);
                o.Normal = UnpackNormal(tex2D(_NormalMap, IN.uv_NormalMap));
                o.Occlusion = lerp(1-_OcclusionDarkWeight, 1, UnpackNormal(tex2D(_OcclusionMap, IN.uv_OcclusionMap))) * _Occlusion;
                o.Metallic = _Metallic;
                o.Smoothness = _Glossiness;
            }
            else
                o.Albedo = noise;
        }
        ENDCG
    }
    FallBack "Transparent/Diffuse"
}