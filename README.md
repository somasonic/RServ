RServ
=====

Project
-------
This is RServ, an as-of-yet incomplete attempt at a plugin-based, event driven lightweight IRC services framework written in Ruby. It is not intended to be NickServ or do any traditional services functions, but rather provide a framework on which Ruby plugins could quickly be developed to use the full power of a psuedoservice, without the fuss.

Protocols are modular, at the moment TS6 (Charybdis) is functional but not production ready.

Dependencies
------------

* Ruby (2.0 compatible)
* configru https://github.com/programble/configru
* ruby-lastfm (lastfm plugin)

IRC
---
Please visit at irc.interlinked.me:6667 (or 6697 for SSL) on channel #rserv for a demonstration bot as well as technical support.

License
=======
This project is made available under the MIT license. A copy of the license text is included below and in the LICENSE file.

License Text
------------
Copyright (C) 2013 Andrew Northall

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
