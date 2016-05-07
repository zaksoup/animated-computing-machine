#!/bin/ruby

require 'yaml'

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
    eval_logic(logic)
    @pipeline
  end

private

  def make_gate_job(gate_type, name, arg0_name, arg1_name, res_name)
    {
      'name' => name,
      'plan' => [{
        'aggregate' => [{
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
      'plan' => [{
        'aggregate' => gets,
      }, {
        'task' => 'print',
        'config' => {
          'platform' => 'linux',
          'image_resource' => {
            'type' => 'docker-image',
            'source' => {'repository' => 'alpine'}
          },
          'inputs' => inputs,
          'run' => {
            'path' => 'sh',
            'args' => ['-exc', echo_cmd]
          }
        }
      }]
    })

    nil
  end

  def eval_set(set_def)

    val = set_def['val']
    name = set_def['in']
    res_name = name + '_res'

    @pipeline.add_resource({
      'name' => name,
      'type' => 's3',
      'source' => {
        'bucket' => 'animated-computing-machine',
        'versioned_file' => name + '/bit',
        'access_key_id' => '{{access-key-id}}',
        'secret_access_key' => '{{secret-access-key}}',
        'region_name' => 'us-west-2'
      }
    })

    @pipeline.add_job({
      'name' => 'set_' + name,
      'plan' => [{
        'get' => 'animated-computing-machine',
      }, {
        'task' => 'set',
        'file' => 'animated-computing-machine/set_bit.yml',
        'params' => [val]
      }, {
        'put' => res_name,
        'params' => {'file' => 'out1/bit'}
      }]
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

