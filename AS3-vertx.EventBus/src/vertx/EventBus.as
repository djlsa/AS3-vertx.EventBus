package vertx
{
	import flash.display.Sprite;
	import com.worlize.websocket.WebSocket;
	import com.worlize.websocket.WebSocketEvent;
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.events.SecurityErrorEvent;
	import flash.text.ime.CompositionAttributeRange;

	/**
	 * ...
	 * @author David
	 */
	public class EventBus
	{
		public static const
			CONNECTING: int = 0,
			OPEN: int = 1,
			CLOSING: int = 2,
			CLOSED: int = 3;

		private var url: String;
		private var socket: WebSocket;
		private var handlerMap: Object = { };
		private var replyHandlers: Object = { };
		private var state: int = EventBus.CONNECTING;
		
		public var onopen: Function = null;
		public var onmessage: Function = null;
		public var onclose: Function = null;
		public var onerror: Function = null;

		public function EventBus(url: String)
		{
			url = url.replace(/^http/, "ws");
			var ws:String = "websocket";
			url += (url.charAt(url.length - 1) == "/") ? ws : "/" + ws;
			socket = new WebSocket(url, "*");
		
			socket.addEventListener(WebSocketEvent.OPEN, function(event: WebSocketEvent): void
			{
				state = OPEN;
				if (onopen != null)
					onopen.call(this);
			});

			socket.addEventListener(WebSocketEvent.CLOSED, function(event: WebSocketEvent): void
			{
				state = CLOSED;
				if (onclose != null)
					onclose.call(this);
			});

			socket.addEventListener(WebSocketEvent.MESSAGE, function(event: WebSocketEvent): void
			{
				var msg: String = event.message.binaryData.toString();
				if (onmessage != null)
					onmessage.call(this, { data: msg } );
				var json: Object = JSON.parse(msg);
				var body: Object = json.body;
				var replyAddress: String = json.replyAddress;
				var address: String = json.address;
				var replyHandler: Function;
				if(replyAddress != "")
				{
					replyHandler = function(reply: Object, replyHandler: Function): void
					{
						this.send(replyAddress, reply, replyHandler);
					};
				}
				var handlers: Array = null;
				if(address in handlerMap)
					handlers = handlerMap[address];
				if (handlers != null)
				{
					var copy: Array = handlers.slice(0);
					for (var i: int  = 0; i < copy.length; i++)
					{
						if (copy[i] != null)
							copy[i](body, replyHandler);
					}
				}
				else
				{
					var handler: Function;
					if (address in replyHandlers)
					{
						handler = replyHandlers[address];
						delete replyHandlers[replyAddress];
						handler.call(this, body, replyHandler);
					}
				}
			});

			socket.addEventListener(IOErrorEvent.IO_ERROR, handleError);
			socket.addEventListener(SecurityErrorEvent.SECURITY_ERROR, handleError);

			socket.connect();
		}
		
		private function handleError(event: Event): void
		{
			if (onerror != null)
				onerror.call(this, event);
		}
		
		public function send(address: String, message: Object, replyHandler: Function): void
		{
			sendOrPub("send", address, message, replyHandler);
		}
		
		public function publish(address: String, message: Object, replyHandler: Function): void
		{
			sendOrPub("publish", address, message, replyHandler);
		}
		
		public function registerHandler(address: String, handler: Function): void
		{
			checkOpen();
			var handlers: Array = null;
			if(address in handlerMap)
				handlers = handlerMap[address];
			if(handlers == null)
			{
				handlers = [handler];
				handlerMap[address] = handlers;
				var msg: Object = { type: "register", address: address };
				socket.sendUTF(JSON.stringify(msg));
			} else {
				handlers[handlers.length] = handler;
			}
		}
		
		public function unregisterHandler(address: String, handler: Function): void
		{
			checkOpen();
			var handlers: Array = null;
			if(address in handlerMap)
				handlers = handlerMap[address];
			if(handlers != null)
			{
				var idx: int = handlers.indexOf(handler);
				if(idx != -1)
					handlers.splice(idx, 1);
				if(handlers.length == 0)
				{
					var msg: Object = { type: "unregister", address: address };
					socket.sendUTF(JSON.stringify(msg));
					delete handlerMap[address];
				}
			}
		}

		public function close(): void
		{
			checkOpen();
			state = CLOSING;
			socket.close();
		}
		
		public function connect(): void
		{
			state = OPEN;
			socket.connect();
		}
		
		public function readyState(): int
		{
			return state;
		}

		private function sendOrPub(sendOrPub: String, address: String, message: Object, replyHandler: Function): void
		{
			checkOpen();
			var envelope: Object = { type: sendOrPub, address: address, body: message };
			if (replyHandler != null)
			{
				var replyAddress: String = makeUUID();
				envelope.replyAddress = replyAddress;
				replyHandlers[replyAddress] = replyHandler;
			}
			var str: String = JSON.stringify(envelope);
			socket.sendUTF(str);
		}

		private function checkOpen(): void
		{
			if (state != OPEN)
				trace("ERROR... invalid state");
		}

		public static function makeUUID(): String
		{
			return"xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".replace(/[xy]/g, function(): String
			{
				return arguments[2] = Math.random() * 16, (arguments[1] == "y" ? arguments[2] & 3 | 8 : arguments[2] | 0).toString(16);
			});
		}
	}
}