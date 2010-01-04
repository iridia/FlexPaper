/*
Copyright 2009 Erik Engström
 
This file is part of FlexPaper.

FlexPaper is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

FlexPaper is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with FlexPaper.  If not, see <http://www.gnu.org/licenses/>.	
*/

package com.devaldi.streaming
{
        import flash.display.Loader;
        import flash.net.URLRequest;
        import flash.net.URLStream;
        import flash.events.IOErrorEvent;
        import flash.events.SecurityErrorEvent;
        import flash.events.Event;
        import flash.events.ProgressEvent;
        import flash.utils.ByteArray;
        import flash.utils.Endian;
        import flash.errors.EOFError;
        
        /**
         * Usage:
         * <pre>
         * var loader:Loader = Loader(addChild(new Loader()));
         * var fLoader:ForcibleLoader = new ForcibleLoader(loader);
         * fLoader.load(new URLRequest('swf7.swf'));
         * </pre>
         */
        public class ForcibleLoader
        {
                public function ForcibleLoader(loader:Loader)
                {
                        this.loader = loader;
                        
                        _stream = new URLStream();
                        _stream.addEventListener(Event.COMPLETE, completeHandler);
                        _stream.addEventListener(IOErrorEvent.IO_ERROR, ioErrorHandler);
                        _stream.addEventListener(SecurityErrorEvent.SECURITY_ERROR, securityErrorHandler);
                }
                
                private var _loader:Loader;
                private var _stream:URLStream;
                
                public function get stream():URLStream
                {
                        return _stream;
                }
                
                public function get loader():Loader
                {
                        return _loader;
                }
                
                public function set loader(value:Loader):void
                {
                        _loader = value;
                }
                
                public function load(request:URLRequest):void
                {
                        _stream.load(request);
                }
                
                private function completeHandler(event:Event):void
                {
                        var inputBytes:ByteArray = new ByteArray();
                        _stream.readBytes(inputBytes);
                        _stream.close();
                        inputBytes.endian = Endian.LITTLE_ENDIAN;
                        
                        if (isCompressed(inputBytes)) {
                                uncompress(inputBytes);
                        }
                        
                        var version:uint = uint(inputBytes[3]);
                        
                        if (version <= 9) {
                                if (version == 8 || version == 9) {
                                        flagSWF9Bit(inputBytes);
                                }
                                else if (version <= 7) {
                                        insertFileAttributesTag(inputBytes);
                                }
                                updateVersion(inputBytes, 9);
                        }
                        
                        loader.loadBytes(inputBytes);
                }
                
                private function isCompressed(bytes:ByteArray):Boolean
                {
                        return bytes[0] == 0x43;
                }
                
                private function uncompress(bytes:ByteArray):void
                {
                        var cBytes:ByteArray = new ByteArray();
                        cBytes.writeBytes(bytes, 8);
                        bytes.length = 8;
                        bytes.position = 8;
                        cBytes.uncompress();
                        bytes.writeBytes(cBytes);
                        bytes[0] = 0x46;
                        cBytes.length = 0;
                }
                
                private function getBodyPosition(bytes:ByteArray):uint
                {
                        var result:uint = 0;
                        
                        result += 3; // FWS/CWS
                        result += 1; // version(byte)
                        result += 4; // length(32bit-uint)
                        
                        var rectNBits:uint = bytes[result] >>> 3;
                        result += (5 + rectNBits * 4) / 8; // stage(rect)
                        
                        result += 2;
                        
                        result += 1; // frameRate(byte)
                        result += 2; // totalFrames(16bit-uint)
                        
                        return result;
                }
                
                private function findFileAttributesPosition(offset:uint, bytes:ByteArray):uint
                {
                        bytes.position = offset;
                        
                        try {
                                for (;;) {
                                        var byte:uint = bytes.readShort();
                                        var tag:uint = byte >>> 6;
                                        if (tag == 69) {
                                                return bytes.position - 2;
                                        }
                                        var length:uint = byte & 0x3f;
                                        if (length == 0x3f) {
                                                length = bytes.readInt();
                                        }
                                        bytes.position += length;
                                }
                        }
                        catch (e:EOFError) {
                        }
                        
                        return NaN;
                }
                
                private function flagSWF9Bit(bytes:ByteArray):void
                {
                        var pos:uint = findFileAttributesPosition(getBodyPosition(bytes), bytes);
                        if (!isNaN(pos)) {
                                bytes[pos + 2] |= 0x08;
                        }
                }
                
                private function insertFileAttributesTag(bytes:ByteArray):void
                {
                        var pos:uint = getBodyPosition(bytes);
                        var afterBytes:ByteArray = new ByteArray();
                        afterBytes.writeBytes(bytes, pos);
                        bytes.length = pos;
                        bytes.position = pos;
                        bytes.writeByte(0x44);
                        bytes.writeByte(0x11);
                        bytes.writeByte(0x08);
                        bytes.writeByte(0x00);
                        bytes.writeByte(0x00);
                        bytes.writeByte(0x00);
                        bytes.writeBytes(afterBytes);
                        afterBytes.length = 0;
                }
                
                private function updateVersion(bytes:ByteArray, version:uint):void
                {
                        bytes[3] = version;
                }
                
                private function ioErrorHandler(event:IOErrorEvent):void
                {
                        loader.contentLoaderInfo.dispatchEvent(new IOErrorEvent(IOErrorEvent.IO_ERROR));
                }
                
                private function securityErrorHandler(event:SecurityErrorEvent):void
                {
                        loader.contentLoaderInfo.dispatchEvent(new SecurityErrorEvent(SecurityErrorEvent.SECURITY_ERROR));
                }
        }
}
