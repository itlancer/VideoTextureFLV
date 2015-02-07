package {
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.display3D.Context3DProfile;
	import flash.events.NetStatusEvent;
	import flash.display3D.Context3DProgramType;
	import flash.display3D.Context3D;
	import flash.display3D.IndexBuffer3D;
	import flash.geom.Matrix3D;
	import flash.net.NetConnection;
	import flash.net.NetStream;
	import flash.display3D.textures.VideoTexture;
	import flash.events.SecurityErrorEvent;
	import flash.display3D.VertexBuffer3D;
	import flash.display3D.Context3DTextureFormat;
	import com.adobe.utils.AGALMiniAssembler;
	import flash.display3D.Program3D;
	import flash.display3D.Context3DVertexBufferFormat;
	import flash.display3D.Context3DBlendFactor;
	
	public class VideoTextureFLV extends Sprite {
		private var context3D:Context3D;
		private var indexbuffer:IndexBuffer3D;
		private var m:Matrix3D = new Matrix3D();
		private var nc:NetConnection;
		private var ns:NetStream;
		private var videoTexture:VideoTexture;
		
		public function VideoTextureFLV() {
			this.addEventListener(Event.ADDED_TO_STAGE, init, false, 0, true);
		}
		
		private function init(e:Event):void {
			this.removeEventListener(Event.ADDED_TO_STAGE, init);
			
			if (stage.stage3Ds.length > 0){
				stage.stage3Ds[0].addEventListener(Event.CONTEXT3D_CREATE, contextCreated, false, 0, true);
				stage.stage3Ds[0].requestContext3DMatchingProfiles(Vector.<String>([Context3DProfile.BASELINE, Context3DProfile.BASELINE_CONSTRAINED, Context3DProfile.BASELINE_EXTENDED, Context3DProfile.STANDARD, Context3DProfile.STANDARD_CONSTRAINED, Context3DProfile.STANDARD_EXTENDED]));
			} else {
				trace("Error: there is no Stage3D available")
			}
		}
		
		private function contextCreated(event:Event):void {
			context3D = stage.stage3Ds[0].context3D;
			context3D.configureBackBuffer(1280, 800, 4, false, false, true);
			trace(context3D.driverInfo);
			
			var vertices:Vector.<Number> = Vector.<Number>([
				0.5, -1, 0, 1, 0,
				0.5, 0.5, 0, 1, 1,
				-1, 0.5, 0, 0, 1,
				-1,-1, 0, 0, 0
			]);
			
			// create the buffer to upload the vertices
			var vertexbuffer:VertexBuffer3D = context3D.createVertexBuffer(4, 5);
			// upload the vertices
			vertexbuffer.uploadFromVector(vertices, 0, 4);
			// create the buffer to upload the indices
			indexbuffer = context3D.createIndexBuffer(6);
			// upload the indices
			indexbuffer.uploadFromVector(Vector.<uint>([0, 1, 2, 2, 3, 0]), 0, 6);
			
			// create the mini assembler
			var vertexShaderAssembler:AGALMiniAssembler = new AGALMiniAssembler();
			// assemble the vertex shader
			vertexShaderAssembler.assemble(Context3DProgramType.VERTEX, "m44 op, va0, vc0\n" + "mov v0, va1");

			var fragmentShaderAssembler:AGALMiniAssembler = new AGALMiniAssembler();
			// assemble the fragment shader
			fragmentShaderAssembler.assemble(Context3DProgramType.FRAGMENT, "tex ft1, v0, fs0 <2d,linear, nomip>\n" + "mov oc, ft1");
			// create the shader program
			var program:Program3D = context3D.createProgram();
			// upload the vertex and fragment shaders
			program.upload(vertexShaderAssembler.agalcode, fragmentShaderAssembler.agalcode);
			
			// set the vertex buffer
			context3D.setVertexBufferAt(0, vertexbuffer, 0, Context3DVertexBufferFormat.FLOAT_3);
			context3D.setVertexBufferAt(1, vertexbuffer, 3, Context3DVertexBufferFormat.FLOAT_2);
			context3D.setBlendFactors(Context3DBlendFactor.ONE, Context3DBlendFactor.ONE);//This line adds alpha channel support
			
			videoTexture = context3D.createVideoTexture();
			context3D.setTextureAt(0, videoTexture);
			
			context3D.setProgram(program);
			m.appendScale(1, -1, 1);
			context3D.setProgramConstantsFromMatrix(Context3DProgramType.VERTEX, 0, m, true);
			
			nc = new NetConnection();
			nc.addEventListener(NetStatusEvent.NET_STATUS, netStatusHandler, false, 0, true);
			nc.addEventListener(SecurityErrorEvent.SECURITY_ERROR, securityErrorHandler, false, 0, true);
			nc.connect(null);
			
		}
		
		private function netStatusHandler(event:NetStatusEvent):void {
			//trace(event.info.code);
			switch (event.info.code){
				case "NetConnection.Connect.Success":
					ns = new NetStream(nc);
					ns.addEventListener(NetStatusEvent.NET_STATUS, netStatusHandler, false, 0, true);
					ns.client = {onMetaData:getMeta, onPlayStatus:onPlayStatus};
					videoTexture.attachNetStream(ns);
					ns.play("video.flv");
					
					this.addEventListener(Event.ENTER_FRAME, render, false, 0, true);
				break;
				case "NetStream.Play.StreamNotFound":
					trace("Stream not found");
				break;
			}
		}
		
		//Metadata handler
		private function getMeta(mdata:Object):void {
			//trace("metadata");
		}
		
		//Seek video to begin after complete
		private function onPlayStatus(infoObject:Object):void {
			ns.seek(0);
		}

		private function securityErrorHandler(event:SecurityErrorEvent):void {
			trace("securityErrorHandler:", event.text);
		}
		
		private function render(event:Event):void {
			context3D.clear(0.2, 0.5, 0.3, 1);//Context3D background color
			context3D.drawTriangles(indexbuffer);
			context3D.present();
		}
		
	}
}
