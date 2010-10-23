# AngryShell

`AngryShell` makes you less angry about running shell commands from ruby.

# Usage
    require 'angry_shell'
    include AngryShell::ShellMethods

    sh("echo Hello World").to_s #=> 'Hello World'
    sh("echo Hello World").ok?  #=> true
    sh("echo Hello World").run  #=> nil

    # the command 'schmortle' doesn't exist :)
    sh("schmortle").to_s #=> ''
    sh("schmortle").ok?  #=> false
    sh("schmortle").run  #=> raises Errno::ENOENT, since schmortle doesn't exist

    begin
      sh("sh -c 'echo hello && exit 1'").run
    rescue AngryShell::ShellError
      $!.result.stdout #=> "hello\n"
      $!.result.ok?    #=> false
    end

## Duck punching

    require 'angry_shell'
    "echo Hello World".sh.to_s #=> 'Hello World'

## License

Copyright (c) 2010 Lachie Cox

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

