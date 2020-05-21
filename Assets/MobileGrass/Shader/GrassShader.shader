// Upgrade NOTE: replaced '_World2Object' with 'unity_WorldToObject'

// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'

// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'
// Upgrade NOTE: replaced '_Projector' with 'unity_Projector'
// Upgrade NOTE: replaced '_ProjectorClip' with 'unity_ProjectorClip'
// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Custom/GrassShader" {
	Properties{
		_MainTex("_MainTex", 2D) = "gray" {}
		_Color("_Color", Color) = (0, 0, 0, 1)
		_WindStrength("_WindStrength", float) = 0.04
		_WindSpeed ("_WindSpeed", float) = 1
		_GrassTex("_GrassTex", 2D) = "black" {}
		//单棵草mesh的节数
		_GrassSeg("_GrassSeg", float) = 5
		//草块中单行草的数量
		_GrassNum("_GrassNum", float) = 50
		//（草块面积）
		_GrassRange("_GrassRange", float) = 3
	}

	Subshader{
			Tags{"RenderType" = "Opaque" }
		Pass{
			Tags{ "LightMode" = "ForwardBase" }
			//Blend SrcAlpha OneMinusSrcAlpha
			cull off
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#include "UnityCG.cginc"
			#include "Lighting.cginc"
			#include "UnityLightingCommon.cginc" // for _LightColor0
			#pragma multi_compile_fwdbase nolightmap nodirlightmap nodynlightmap novertexlight
			#include "AutoLight.cginc"
			#define PI 6.2831852
			uniform float4x4 GrassMatrix;
			struct v2f {
				float2 uv : TEXCOORD0;
				float4 pos : SV_POSITION;
				fixed4 diff : COLOR0;
				SHADOW_COORDS(1) // put shadows data into TEXCOORD1
			};

			struct appdata
			{
				float2 uv : TEXCOORD0;
				float4 vertex : POSITION;
				float3 normal : NORMAL;
				float4 color : COLOR;
				//UNITY_VERTEX_INPUT_INSTANCE_ID
			};


			float _WindStrength;
			float _WindSpeed;
			inline float windStrength(float3 pos)
			{
				return pos.x + _Time.w*_WindSpeed + 5 * cos(0.01f*pos.z + _Time.y*_WindSpeed * 0.2f % PI)
					+ 4 * sin(0.05f*pos.z - _Time.y*_WindSpeed*0.15f % PI)
					+ 4 * sin(0.2f*pos.z + _Time.y*_WindSpeed * 0.2f % PI)
					+ 2 * cos(0.6f*pos.z - _Time.y*_WindSpeed*0.4f % PI);
			}


			inline float2 wind(float3 pos)
			{
				float3 realPos = pos;
				float2 result = _WindStrength * sin(0.7 * windStrength(realPos)) *  cos(0.15f*windStrength(realPos));
				return result;
			}

			sampler2D _GrassTex;
			float _GrassSeg;
			float _GrassNum;
			float _GrassRange;

			//SV_VertexID，顶点id.语义需要指定#pragma target es3.0。但是此shader中并没有指定也没有问题。
			//Android 4.3也就是API level 18，就开始支持es 3.0了。
			v2f vert(appdata v, uint vid : SV_VertexID)
			//v2f vert(appdata v)
			{
				v2f o;
				float index = floor(vid / ((_GrassSeg + 1) * 2));//此顶点在这颗草中的索引
				float grid = _GrassRange / _GrassNum;
				float row = floor(index / _GrassNum);
				float col = index % _GrassNum;
				float4 objectPos = float4(-_GrassRange / 2 + row * grid, 0, -_GrassRange / 2 + col * grid, 1);
				//float4 worldPos1 = mul(unity_ObjectToWorld, objectPos);
				float4 worldPos1 = mul(_Object2World, objectPos);				
				float4 vertex = v.vertex;
				
				
				//float3 worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
				float3 worldPos = mul(_Object2World, v.vertex).xyz;
				float3 randCalcPos = worldPos;
				float2 windDir = wind(randCalcPos);
				//float2 windDir = wind(v.vertex.xyz);
				
				float4 grassuv1 = mul(GrassMatrix, worldPos1);
				float2 grassuv2 = grassuv1.xy / grassuv1.w * 0.5 + 0.5;//由（-1，1）到（0，1）
#if UNITY_UV_STARTS_AT_TOP
				grassuv2.y = 1 - grassuv2.y;
#endif

				//通过采样纹理的颜色获得数值，改变顶点的位置
				float4 n = tex2Dlod(_GrassTex, float4(grassuv2, 0, 0));
				n.xz = (n.xz - 0.5) * 2;//0，1转换到-1，1
				float2 off = (windDir.xy) * pow(v.vertex.y * 2, 2);// +n.xyz;
				v.vertex.y -= 10 * dot(off, off);
				float2 newOff = off * (1 - n.g) + normalize(n.xz) * v.vertex.y * n.g * 0.6;
				v.vertex.y *= (1 - n.g);//如果绿色值为0，则不会有影响(此处诡异需要除以100)。注意，草在场景中的y要与父级的y值相反，中间层级保持y为0
				//off = float2(-0.3, 0) * v.vertex.y;
				v.vertex.xz += newOff*3;


				//o.pos = mul(UNITY_MATRIX_VP, float4(worldPos, 1));
				o.pos = mul(UNITY_MATRIX_MVP, v.vertex);
				//o.pos = UnityObjectToClipPos(vertex);
				o.uv = v.uv;
				half3 worldNormal = UnityObjectToWorldNormal(v.normal);
				half nl = max(0, dot(worldNormal, _WorldSpaceLightPos0.xyz));
				o.diff = nl * _LightColor0;
				o.diff *= v.color;
				o.diff.rgb += +ShadeSH9(half4(worldNormal, 1));
				TRANSFER_SHADOW(o)
				return o;
			}

			sampler2D _MainTex;
			sampler2D _AlphaTex;
			float4 _Color;
			float4 frag(v2f i) : SV_Target
			{
				half2 uv = i.uv;
				float4 texS = tex2D(_MainTex, uv);
				texS *= i.diff * 1.3;
				fixed shadow = SHADOW_ATTENUATION(i);
				texS *= shadow;
				return texS * _Color * 1.2;
			}
			ENDCG
		}
	}

	//FallBack "Custom/GrassShaderFallBack"
}
