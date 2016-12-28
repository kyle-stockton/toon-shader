////////////////////////////////////////
//Name:			ToonShader_V2.shader
//Author:		Kyle Stockton
//Date:			25 June 2014
//Description:	Toon shader with variable dropoff
///////////////////////////////////////////////////////////////////////////////

Shader "ToonShader V2" {
	Properties {
		_Color ("Color Tint", Color) = (1.0,1.0,1.0,1.0)
		_Diffuse ("Diffuse", 2D) = "white" {}
		_CelLevelA ("  First Light Level", Range(0.0,2.0)) = 1.0
		_CelThreshA ("First Shade Cutoff", Range(0.0,1.0)) = 0.95
		_CelLevelB ("  Second Light Level", Range(0.0,2.0)) = 0.7
		_CelThreshB ("Second Shade Cutoff", Range(0.0,1.0)) = 0.5
		_CelLevelC ("  Third Light Level", Range(0.0,2.0)) = 0.35
		_CelThreshC ("Third Shade Cutoff", Range(0.0,1.0)) = 0.05
		_CelLevelD ("  Fourth Light Level", Range(0.0,2.0)) = 0.1
		_OutlineColor ("Outline Color", Color) = (0,0,0,1)
		_OutwardOutlineThickness ("Outline Thickness", Range (.002, 0.03)) = .005
	}

	SubShader {
		Tags { "RenderType"="Opaque"}

		//Outline Pass
		Pass {
		
			Tags { "LightMode" = "ForwardBase" }
			Cull Front

			CGPROGRAM

			#include "UnityCG.cginc"
			#pragma vertex vert
			#pragma fragment frag
	
			struct vertexInput {
				half4 vertex : POSITION;
				half3 normal : NORMAL;
			};

			struct vertexOutput {
				half4 position : SV_POSITION;
			};
	
			uniform fixed _OutwardOutlineThickness;
			uniform fixed4 _OutlineColor;
					
			vertexOutput vert(vertexInput i) {
				vertexOutput o;
		
				o.position = mul(UNITY_MATRIX_MVP, i.vertex);
				fixed3 norm   = mul ((float3x3)UNITY_MATRIX_IT_MV, i.normal);
				fixed2 offset = TransformViewToProjection(norm.xy);
				o.position.xy += offset * o.position.z * _OutwardOutlineThickness;
		
				return o;
			}
			fixed4 frag (vertexOutput i): COLOR {
				return fixed4(_OutlineColor.xyz,1.0);
			}
			ENDCG
		}
		
		//First diffuse pass
		Pass {
			Tags {"LightMode" = "ForwardBase" "RenderType" = "Opaque"}
			Blend One Zero

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#include "UnityCG.cginc"

			//user defined variables
			uniform sampler2D _Diffuse;
			uniform half4 _Diffuse_ST;
			uniform fixed4 _Color;
			uniform fixed _CelLevelA;
			uniform fixed _CelThreshA;
			uniform fixed _CelLevelB;
			uniform fixed _CelThreshB;
			uniform fixed _CelLevelC;
			uniform fixed _CelThreshC;
			uniform fixed _CelLevelD;
			uniform fixed4 _OutlineColor;
			
			//Unity defined variables
			uniform fixed4 _LightColor0;
			
			//base input structs
			struct vertexInput{
				half4 vertex : POSITION;
				half3 normal : NORMAL;
				half4 texcoord : TEXCOORD0;
			};
			struct vertexOutput{
				half4 position : SV_POSITION;
				half4 tex : TEXCOORD0;
				half4 worldPosition : TEXCOORD1;
				fixed3 normalDir : TEXCOORD2;
			};
			
			//vertex function
			
			vertexOutput vert(vertexInput i) {
				vertexOutput o;
				
				o.worldPosition = mul(_Object2World, i.vertex);
				o.normalDir = normalize( mul( float4( i.normal, 0.0 ), _World2Object ).xyz );
				o.position = mul(UNITY_MATRIX_MVP, i.vertex);
				o.tex = i.texcoord;
				
				return o;
			}
			
			//fragment function
			
			fixed4 frag(vertexOutput o) : COLOR
			{
				fixed3 normalDirection = o.normalDir;
				fixed3 viewDirection = normalize( _WorldSpaceCameraPos.xyz - o.worldPosition.xyz );
				fixed3 lightDirection;
				fixed3 rampFactor;
				half attenuation;
				
				if(_WorldSpaceLightPos0.w == 0.0){ //directional light
						attenuation = 1.0;
						lightDirection = normalize(_WorldSpaceLightPos0.xyz);
					}else{
						half3 fragmentToLightSource = _WorldSpaceLightPos0.xyz - o.worldPosition.xyz;
						half distance = length(fragmentToLightSource);
						attenuation = 1.0/distance;
						lightDirection = normalize (fragmentToLightSource);
				}
				fixed3 intensity = (dot(normalDirection, lightDirection));
				fixed intensityMax = max(max(intensity.x, intensity.y), intensity.z);

          		//if: directional light, else: point light
 									
				if (intensityMax > _CelThreshA) {
						rampFactor = (_CelLevelA,_CelLevelA,_CelLevelA);
					} else if (intensityMax > _CelThreshB){
						rampFactor = (_CelLevelB,_CelLevelB,_CelLevelB);
					} else if (intensityMax > _CelThreshC){
						rampFactor = (_CelLevelC,_CelLevelC,_CelLevelC);						
					} else {
						rampFactor = (_CelLevelD,_CelLevelD,_CelLevelD);
				}						
				
				//Lighting
				fixed3 diffuseReflection = attenuation * _LightColor0.xyz * rampFactor;
				fixed3 lightResult = UNITY_LIGHTMODEL_AMBIENT.xyz + diffuseReflection;

				//Texture Maps
				fixed4 tex = tex2D(_Diffuse, o.tex.xy * _Diffuse_ST.xy + _Diffuse_ST.zw);
				
				return float4(tex.xyz * lightResult * _Color.xyz, 1.0);
			}
			
			ENDCG
		}
		
		//Second diffuse pass necessary for multiple lights and point lights
		Pass {
			Tags {"LightMode" = "ForwardAdd" "RenderType" = "Opaque"}
			Blend One One

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#include "UnityCG.cginc"

			//user defined variables
			uniform sampler2D _Diffuse;
			uniform half4 _Diffuse_ST;
			uniform fixed4 _Color;
			uniform fixed _CelLevelA;
			uniform fixed _CelThreshA;
			uniform fixed _CelLevelB;
			uniform fixed _CelThreshB;
			uniform fixed _CelLevelC;
			uniform fixed _CelThreshC;
			uniform fixed _CelLevelD;
			uniform fixed4 _OutlineColor;
			
			//Unity defined variables
			uniform fixed4 _LightColor0;
			
			//base input structs
			struct vertexInput{
				half4 vertex : POSITION;
				half3 normal : NORMAL;
				half4 texcoord : TEXCOORD0;
			};
			struct vertexOutput{
				half4 position : SV_POSITION;
				half4 tex : TEXCOORD0;
				half4 worldPosition : TEXCOORD1;
				fixed3 normalDir : TEXCOORD2;
			};
			
			//vertex function
			
			vertexOutput vert(vertexInput i) {
				vertexOutput o;
				
				o.worldPosition = mul(_Object2World, i.vertex);
				o.normalDir = normalize( mul( float4( i.normal, 0.0 ), _World2Object ).xyz );
				o.position = mul(UNITY_MATRIX_MVP, i.vertex);
				o.tex = i.texcoord;
				
				return o;
			}
			
			//fragment function
			
			fixed4 frag(vertexOutput o) : COLOR
			{
				fixed3 normalDirection = o.normalDir;
				fixed3 viewDirection = normalize( _WorldSpaceCameraPos.xyz - o.worldPosition.xyz );
				fixed3 lightDirection;
				fixed3 rampFactor;
				half attenuation;

				//if: directional light, else: point light				
				if(_WorldSpaceLightPos0.w == 0.0){
						attenuation = 1.0;
						lightDirection = normalize(_WorldSpaceLightPos0.xyz);
					}else{
						half3 fragmentToLightSource = _WorldSpaceLightPos0.xyz - o.worldPosition.xyz;
						half distance = length(fragmentToLightSource);
						attenuation = 1.0/distance;
						lightDirection = normalize (fragmentToLightSource);
				}

				//falloff level calculation
				fixed3 intensity = (dot(normalDirection, lightDirection));
				half intensityMax = max(max(intensity.x, intensity.y), intensity.z);

				if (intensityMax > _CelThreshA) {
						rampFactor = (_CelLevelA,_CelLevelA,_CelLevelA);
					} else if (intensityMax > _CelThreshB){
						rampFactor = (_CelLevelB,_CelLevelB,_CelLevelB);
					} else if (intensityMax > _CelThreshC){
						rampFactor = (_CelLevelC,_CelLevelC,_CelLevelC);						
					} else {
						rampFactor = (_CelLevelD,_CelLevelD,_CelLevelD);
				}						
				
				//Lighting
				fixed3 diffuseReflection = attenuation * _LightColor0.xyz * rampFactor;

				//Texture Maps
				fixed4 tex = tex2D(_Diffuse, o.tex.xy * _Diffuse_ST.xy + _Diffuse_ST.zw);
				
				return float4(tex.xyz * diffuseReflection * _Color.xyz, 1.0);
			}
			
			ENDCG
		}

	}
	Fallback "Diffuse"
}






















