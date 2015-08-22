## unhide - export symbols with “hidden” visibility.

Since Swift 1.2 (Xcode 6.3) "internal" symbols of Swift frameworks are
given "hidden" C [visibility](https://developer.apple.com/library/mac/documentation/DeveloperTools/Conceptual/CppRuntimeEnv/Articles/SymbolVisibility.html)
to prevent them being accessed from outside the framework.
This is a problem for programs like 
[injectionforxcode](https://github.com/johnno1962/injectionforxcode)
which need to access these symbols when a class from the framework 
is "injected" by dynamically loading a new version of the class.

This binary reverses this hiding and takes a framework name followed
by a list of object files to be patched to export any "hidden" symbols
so they can be accessed in global scope by the run time loader. This is
in preference to having to make the symbols public in the Swift source.

To use, build this project and add a "Run Script" build phase to the
target that builds the framework just after linking that contains:

```shell
    UNHIDE=~/bin/unhide.sh
    if [ -f $UNHIDE ]; then
        $UNHIDE
    else
        echo "File $UNHIDE used for code Injection does not exist."
    fi
```

This will patch the object files of the framework project to export all
symbols defined on the package and then re-link the framework executable.
If it's necessary to link the framework with another framework copy the
contents of the ~/bin/unhide.sh script into the "Run Script" build phase
and edit the command that re-links the framework. 

### MIT License

Copyright (C) 2015 John Holdsworth

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

