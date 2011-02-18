require 'eg.helper'

eg 'popen4 - normal, exahust io' do
  out = nil
  AngryShell::Shell.new.popen4(:cmd => 'echo Hello') do |cid,ipc|
    out = ipc.stdout.read
  end

  Assert(out == "Hello\n")
end

eg 'popen4 - normal, stream io' do
  out = nil
  AngryShell::Shell.new.popen4(:cmd => 'echo Hello', :stream => true) do |cid,ipc|
    out = ipc.stdout.read
  end

  Assert(out == "Hello\n")
end




eg 'popen4 - error' do
  begin
    AngryShell::Shell.new.popen4(:cmd => 'casplortleecho Hello') do |cid,ipc|
    end
    raised = false
  rescue Errno::ENOENT
    raised = true
  end

  Assert(raised)
end


eg 'cmd is a proc' do
  Assert( AngryShell::Shell.new(lambda { puts "hello world" }).to_s == "hello world" )
end


eg 'run' do
  AngryShell::Shell.new("echo Whats happening").run
  Assert( :didnt_raise )
end

eg 'ok?' do
  Assert( AngryShell::Shell.new("echo Whats happening").ok? )
end


eg 'to_s' do
  Assert( AngryShell::Shell.new("echo -n Whats happening").to_s == "Whats happening" )
end

eg.helpers do
  include AngryShell::ShellMethods
end

eg 'helper' do
  Assert( sh("echo Something").to_s == "Something" )
end

eg 'helper - error' do
  raised = false
  begin
    sh("sh -c 'echo hello && exit 1'").run
  rescue AngryShell::ShellError
    raised = true
    Assert( $!.result.stdout == "hello\n" )
    Assert( ! $!.result.ok? )
  end

  Assert( raised )
end
