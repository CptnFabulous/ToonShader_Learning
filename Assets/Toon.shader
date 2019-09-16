Shader "Roystan/Toon"
{
	Properties
	{
		_Color("Color", Color) = (0.5, 0.65, 1, 1)
		_MainTex("Main Texture", 2D) = "white" {}

		[HDR]
		_AmbientColor("Ambient Color", Color) = (0.4,0.4,0.4,1)

		[HDR]
		_SpecularColor("Specular Color", Color) = (0.9,0.9,0.9,1)
		_Glossiness("Glossiness", Float) = 32

		// Light rim
		[HDR]
		_RimColor("Rim Color", Color) = (1,1,1,1)
		_RimAmount("Rim Amount", Range(0, 1)) = 0.716
		_RimThreshold("Rim Threshold", Range(0, 1)) = 0.1
	}
	SubShader
	{
		Pass
		{
			Tags
			{
				"LightMode" = "ForwardBase" // Requests lighting data
				"PassFlags" = "OnlyDirectional" // Only requests lighting data from main directional light
			}

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_fwdbase // For shadows
			
			#include "UnityCG.cginc"
			#include "Lighting.cginc"
			#include "AutoLight.cginc" // For shadows

			struct appdata
			{
				float4 vertex : POSITION;				
				float4 uv : TEXCOORD0;
				float3 normal : NORMAL; // Object normal data
			};

			struct v2f
			{
				float4 pos : SV_POSITION;
				float2 uv : TEXCOORD0;
				float3 viewDir : TEXCOORD1;
				float3 worldNormal : NORMAL; // Object normal data
				SHADOW_COORDS(2) // For shadows
			};

			sampler2D _MainTex;
			float4 _MainTex_ST;
			
			v2f vert (appdata v)
			{
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				o.worldNormal = UnityObjectToWorldNormal(v.normal); // Converts normal from object space to world space
				o.viewDir = WorldSpaceViewDir(v.vertex); // Calculates direction from the current vertex towards the camera
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				TRANSFER_SHADOW(o) // For shadows
				return o;
			}
			
			float4 _Color;
			float4 _AmbientColor;

			float _Glossiness;
			float4 _SpecularColor;

			// Rim lighting
			float4 _RimColor;
			float _RimAmount;
			float _RimThreshold;

			float4 frag (v2f i) : SV_Target
			{
				float3 normal = normalize(i.worldNormal); // 

				float NdotL = dot(_WorldSpaceLightPos0, normal); //
				
				
				float shadow = SHADOW_ATTENUATION(i);
				float lightIntensity = smoothstep(0, 0.01, NdotL * shadow); // 'Toonifies' the shadow by setting all light values to either 1 or 0, removing gradients and making it a solid colour. Also alters based on shadow.
				//float lightIntensity = smoothstep(0, 0.01, NdotL); // 'Toonifies' the shadow by setting all light values to either 1 or 0, removing gradients and making it a solid colour.

				float4 light = lightIntensity * _LightColor0;
				
				float3 viewDir = normalize(i.viewDir);

				float3 halfVector = normalize(_WorldSpaceLightPos0 + viewDir);
				float NdotH = dot(normal, halfVector);

				// Reflection effect
				float specularIntensity = pow(NdotH * lightIntensity, _Glossiness * _Glossiness);
				float specularIntensitySmooth = smoothstep(0.005, 0.01, specularIntensity); // 'Toonifies' reflection
				float4 specular = specularIntensitySmooth * _SpecularColor;

				// Rim lighting effect
				float4 rimDot = 1 - dot(viewDir, normal);
				float rimIntensity = rimDot * pow(NdotL, _RimThreshold);
				rimIntensity = smoothstep(_RimAmount - 0.01, _RimAmount + 0.01, rimIntensity);
				float4 rim = rimIntensity * _RimColor;

				float4 sample = tex2D(_MainTex, i.uv);

				return _Color * sample * (_AmbientColor + light + specular + rim); // Combines effects together
			}
			ENDCG
		}

		UsePass "Legacy Shaders/VertexLit/SHADOWCASTER" // For shadows
	}
}