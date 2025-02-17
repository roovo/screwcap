require 'spec_helper'

describe "Screwcap::Tasks" do
  it "should have a task-like structure" do
    task = Screwcap::Task.new :name => :test do
      run "test"
    end

    task.__commands.should have(0).__commands
    task.__build_commands
    task.__commands.should_not be_nil
    task.should have(1).__commands

    task.__commands[0][:type].should == :remote
    task.__commands[0][:from].should == :test
    task.__commands[0][:command].should == "test"
  end

  it "should be able to build commands" do
    unknown = Screwcap::Task.new :name => :unknown_action do
      run "unknown"
    end

    task = Screwcap::Task.new :name => :test do
      run "test"
      unknown_action
    end

    commands = task.__build_commands([unknown])
    task.__built_commands.should_not == []
    commands.size.should == 2

    commands[0][:type].should == :remote
    commands[0][:from].should == :test
    commands[0][:command].should == "test"

    commands[1][:type].should == :remote
    commands[1][:from].should == :unknown_action
    commands[1][:command].should == "unknown"
  end

  it "should throw an error if we cannot find a command" do
    task = Screwcap::Task.new :name => :test do
      run "test"
      unknown_action
    end

    lambda {task.__build_commands([task])  }.should raise_error(NoMethodError)
  end

  it "should be able to create variables" do
    task = Screwcap::Task.new :name => :test do
      set :blaster, "stun"
      run "fire #{blaster}"
    end
    task.__build_commands
    task.blaster.should == "stun"
    task.__commands.first[:command].should == "fire stun"
  end

  it  "command sets should inherit the parent's variables" do
    subsub = Screwcap::Task.new :name => :subsubtask do
      set :from, "venus"
      run "fly to #{where} from #{from}"
    end

    sub = Screwcap::Task.new :name => :subtask do
      set :from, "mars"
      run "fly to #{where} from #{from}"
      subsubtask
    end

    task = Screwcap::Task.new :name => :task do
      set :where, "the moon"
      set :from, "earth"
      run "fly to #{where} from #{from}"
      subtask
    end

    commands = task.__build_commands([sub, subsub])
    commands[0][:from].should == :task
    commands[0][:command].should == "fly to the moon from earth"

    commands[1][:from].should == :subtask
    commands[1][:command].should == "fly to the moon from mars"

    commands[2][:from].should == :subsubtask
    commands[2][:command].should == "fly to the moon from venus"
  end

  it "should respond to :before or before_ calls" do
    before = Screwcap::Task.new :name => :do_before do
      run "before"
    end
    task = Screwcap::Task.new :name => :test, :before => :do_before do
      run "task"
    end

    before2 = Screwcap::Task.new :name => :before_deploy do
      run "before"
    end

    task2 = Screwcap::Task.new :name => :deploy do
      run "deploy"
    end

    commands = task.__build_commands([before])
    commands.map {|c| c[:command] }.should == ["before","task"]

    commands = task2.__build_commands([before2])
    commands.map {|c| c[:command] }.should == ["before","deploy"]
  end

  it "should respond to :after or after_ calls" do
    after = Screwcap::Task.new :name => :do_after do
      run "after"
    end
    task = Screwcap::Task.new :name => :test, :after => :do_after do
      run "task"
    end

    after2 = Screwcap::Task.new :name => :after_deploy do
      run "after"
    end

    task2 = Screwcap::Task.new :name => :deploy do
      run "deploy"
    end

    commands = task.__build_commands([after])
    commands.map {|c| c[:command] }.should == ["task","after"]

    commands = task2.__build_commands([after2])
    commands.map {|c| c[:command] }.should == ["deploy", "after"]
  end

  it "should handle before and after inside a task" do
    do_other_task = Screwcap::Task.new :name => :other_task do
      run "task"
    end
    task = Screwcap::Task.new :name => :task do
      before :other_task do
        run "before"
      end
      after :other_task do
        run "after"
      end

      other_task
    end

    commands = task.__build_commands([do_other_task])
    commands.map {|c| c[:command] }.should == %w(before task after)
  end

  it "before and after call blocks can call command sets just like everything else" do
    special = Screwcap::Task.new :name => :run_special_command do
      run "special"
    end
    other = Screwcap::Task.new :name => :other_task do
      run "other"
    end

    task = Screwcap::Task.new :name => :task do
      before :other_task do
        run_special_command
      end
      after :other_task do
        run "after"
      end
      other_task
    end
    commands = task.__build_commands([special, other])
    commands.map {|c| c[:command] }.should == %w(special other after)
  end

  it "should be able to handle multiple befores inside" do
    special = Screwcap::Task.new :name => :run_special_command do
      run "special"
    end
    other = Screwcap::Task.new :name => :other_task do
      run "other"
    end

    task = Screwcap::Task.new :name => :task do
      before :other_task do
        run_special_command
      end
      before :other_task do
        run "moon_pie"
      end
      after :other_task do
        run "after"
      end
      other_task
    end
    commands = task.__build_commands([special, other])
    commands.map {|c| c[:command] }.should == %w(special moon_pie other after)
  end

  it "should be able to handle multiple befores outside" do
    before1 = Screwcap::Task.new :name => :do1 do
      run "do1"
    end

    before2 = Screwcap::Task.new :name => :do2 do
      run "do2"
    end

    task = Screwcap::Task.new :name => :new_task, :before => [:do1, :do2] do
      run "task"
    end

    commands = task.__build_commands([before1, before2])
    commands.map {|c| c[:command] }.should == %w(do1 do2 task)
  end

  it "should be able to run before on deeply nested command sets" do
    n1 = Screwcap::Task.new :name => :nested do
      inner_nested
    end

    n2 = Screwcap::Task.new :name => :inner_nested do
      run "inner_nested"
      inner_inner_nested
    end

    n3 = Screwcap::Task.new :name => :inner_inner_nested do
      run "inner_inner_nested"
    end

    task = Screwcap::Task.new :name => :deploy do
      before :inner_inner_nested do
        run "before_inner_inner_nested"
      end
      after :inner_nested do
        run "after_inner_nested"
      end
      nested
    end

    commands = task.__build_commands [n1, n2, n3]
    commands.map {|c| c[:command] }.should == %w(inner_nested before_inner_inner_nested inner_inner_nested after_inner_nested)
  end

  it "before and after should be able to run command sets on their own" do
    n1 = Screwcap::Task.new :name => :release_the_hounds do
      run "release_the_hounds"
    end

    n2 = Screwcap::Task.new :name => :lock_the_gate do
      run "lock_the_gate"
    end

    n3 = Screwcap::Task.new :name => :unlock_the_gate do
      run "unlock_the_gate"
    end

    task = Screwcap::Task.new :name => :deploy_the_animals do
      before(:release_the_hounds) { unlock_the_gate }
      after(:release_the_hounds) { lock_the_gate }
      release_the_hounds
    end

    commands = task.__build_commands [n1, n2, n3]
    commands.map {|c| c[:command] }.should == %w(unlock_the_gate release_the_hounds lock_the_gate)
  end

  it "has an ex command" do
    task = Screwcap::Task.new :name => :task do
      @test = "asdf"
      ex { @test = "fdsa" }
    end

    commands = task.__build_commands([task])
    commands[0][:type].should == :block
  end

  it "should be able to call other tasks" do
    t1 = Screwcap::Task.new :name => :release_the_hounds do
      run "release_the_hounds"
    end

    t2 = Screwcap::Task.new :name => :lock_the_gate do
      run "lock_the_gate"
    end

    t3 = Screwcap::Task.new :name => :release_the_hounds_and_lock_the_gate do
      release_the_hounds
      lock_the_gate
    end

    commands = t3.__build_commands [t1, t2]
    commands.map {|c| c[:command] }.should == %w(release_the_hounds lock_the_gate)
  end
end
