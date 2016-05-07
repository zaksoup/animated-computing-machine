#!/bin/ruby

require 'yaml'
require 'digest'

class Pipeline
  attr_accessor :jobs, :resources

  def initialize
    @jobs = []
    @resources = []
  end

  def add_job(job)
    @jobs << job unless have_job(job['name'])
  end

  def add_resource(res)
    @resources << res unless have_res(res['name'])
  end

  def to_yaml
    {
      'jobs' => @jobs,
      'resources' => @resources
    }.to_yaml
  end

private

  def have_job(job_name)
    @jobs.find{|job| job['name'] == job_name}
  end

  def have_res(res_name)
    @resources.find{|res| res['name'] == res_name}
  end
end

class PipelineEngineer

  def construct(logic)
    @pipeline = Pipeline.new
    @pipeline.add_resource(make_git_resource)
    @pipeline.add_resource(make_manual_trigger_resource)
    @pipeline.add_job(make_manual_trigger_job)
    eval_logic(logic)
    @pipeline
  end

private

  def access_key_id
    'AKIA_secret_key'
  end

  def secret_access_key
    'secret_access_key'
  end

  def make_s3_resource(name)
    md5 = Digest::MD5.new
    md5.update name
    {
      'name' => name,
      'type' => 's3',
      'source' => {
        'bucket' => 'animated-computing-machine-tom',
        'versioned_file' => "res#{md5.hexdigest}/bit",
        'access_key_id' => access_key_id,
        'secret_access_key' => secret_access_key,
        'region_name' => 'us-west-2'
      }
    }
  end

  def make_git_resource
    {
      'name' => 'animated-computing-machine',
      'type' => 'git',
      'source' => {
        'uri' => 'https://github.com/zaksoup/animated-computing-machine.git',
        'branch' => 'master'
      }
    }
  end

  def make_manual_trigger_job
    cmd = "date > trigger/value"
    outputs = [{'name' => 'trigger'}]
    {
      'name' => 'trigger',
      'plan' => [
        make_sh_task('trigger', [], cmd, outputs),
        {
          'put' => 'trigger',
          'params' => {'file' => 'trigger/value'},
        }
      ]
    }
  end

  def make_manual_trigger_resource
    {
      'name' => 'trigger',
      'type' => 's3',
      'source' => {
        'bucket' => 'animated-computing-machine-tom',
        'versioned_file' => "trigger/value",
        'access_key_id' => access_key_id,
        'secret_access_key' => secret_access_key,
        'region_name' => 'us-west-2'
      }
    }
  end

  def make_gate_job(gate_type, name, arg0_name, arg1_name, res_name)
    {
      'name' => name,
      'plan' => [{
        'aggregate' => [{
          'get' => 'animated-computing-machine',
        }, {
          'get' => 'in1',
          'trigger' => true,
          'resource' => arg0_name
        }, {
          'get' => 'in2',
          'trigger' => true,
          'resource' => arg1_name
        }],
      }, {
        'task' => 'and',
        'file' => "animated-computing-machine/gates/#{gate_type}.yml",
      }, {
        'put' => 'out',
        'resource' => res_name,
        'params' => {'file' => 'out/bit'},
      }]
    }
  end

  def eval_gate(gate_type, gate)
    arg0_name = eval_logic(gate[gate_type][0])
    arg1_name = eval_logic(gate[gate_type][1])

    name = [gate_type, '(', arg0_name, ',', arg1_name, ')'].join
    res_name = name + '_res'

    @pipeline.add_resource(make_s3_resource res_name)
    @pipeline.add_job make_gate_job(gate_type, name, arg0_name, arg1_name, res_name)

    res_name
  end

  def eval_print(node)

    arg_names = node['print'].map{|arg|
      eval_logic(arg)
    }

    gets = []
    inputs = []
    echo_cmd = 'echo '
    arg_names.each_with_index.map{|arg_name,i|
      gets << {
        'get' => "in#{i}",
        'trigger' => true,
        'resource' => arg_name
      }

      inputs << {'name' => "in#{i}"}

      echo_cmd += "$(cat in#{i}/bit)"
    }

    @pipeline.add_job({
      'name' => 'print',
      'plan' => [
        {'aggregate' => gets},
        make_sh_task('print', inputs, echo_cmd, []),
      ]
    })

    nil
  end

  def make_sh_task(name, inputs, cmd, outputs)
    {
      'task' => name,
      'config' => {
        'platform' => 'linux',
        'image_resource' => {
          'type' => 'docker-image',
          'source' => {'repository' => 'alpine'}
        },
        'inputs' => inputs,
        'outputs' => outputs,
        'run' => {
          'path' => 'sh',
          'args' => ['-exc', cmd]
        }
      }
    }
  end

  def eval_set(set_def)

    val = set_def['val']
    name = set_def['in']
    res_name = name + '_res'

    inputs = []
    outputs = [{'name' => res_name, 'path' => 'out'}]
    cmd = "echo #{val} > out/bit"

    @pipeline.add_resource(make_s3_resource res_name)

    @pipeline.add_job({
      'name' => 'set_' + name,
      'plan' => [{
          'get' => 'trigger',
          'trigger' => true,
          'passed' => ['trigger']
        },
        make_sh_task('set', inputs, cmd, outputs),
        {
          'put' => res_name,
          'params' => {'file' => "#{res_name}/bit"},
        }
      ]
    })

    res_name
  end

  def eval_logic(node)
    if node['xor']
      eval_gate('xor', node)
    elsif node['or']
      eval_gate('or', node)
    elsif node['and']
      eval_gate('and', node)
    elsif node['in']
      eval_set(node)
    elsif node['print']
      eval_print(node)
    else
      puts 'wtf is this? ' + node.inspect
      exit(1)
    end
  end
end

logic = YAML.load(IO.read(ARGV[0]))
puts PipelineEngineer.new.construct(logic).to_yaml

