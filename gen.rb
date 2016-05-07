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

class PipelineEngineer

  def construct(logic)
    @pipeline = Pipeline.new

    arg1 = logic['print'][0]
    arg2 = logic['print'][1]
    arg3 = logic['print'][2]

    eval_print(
      eval_logic(arg1),
      eval_logic(arg2),
      eval_logic(arg3)
    )

    @pipeline
  end

  def eval_gate(gate_type, gate)
    arg0_name = eval_logic(gate[gate_type][0])
    arg1_name = eval_logic(gate[gate_type][1])

    name = [gate_type, '_', arg0_name, '_', arg1_name].join
    res_name = name + '_res'

    @pipeline.add_job make_gate_job(gate_type, name, arg0_name, arg1_name, res_name)

    res_name
  end

  def eval_print(arg0_name, arg1_name, arg2_name)

    @pipeline.add_job({
      'name' => 'print',
      'plan' => [{
        'aggregate' => [{
          'get' => 'in1',
          'trigger' => true,
          'resource' => arg0_name
        }, {
          'get' => 'in2',
          'trigger' => true,
          'resource' => arg1_name
        }, {
          'get' => 'in3',
          'trigger' => true,
          'resource' => arg2_name
        }],
      }, {
        'task' => 'print',
        'config' => {
          'platform' => 'linux',
          'image_resource' => {
            'type' => 'docker-image',
            'source' => {'repository' => 'alpine'}
          },
          'inputs' => [
            {'name' => 'in1'},
            {'name' => 'in2'},
            {'name' => 'in3'},
          ],
          'run' => {
            'path' => 'sh',
            'args' => ['-exc', 'echo "$(cat in1/bit)$(cat in2/bit)$(cat in3/bit)"']
          }
        }
      }]
    })

    nil
  end

  def eval_set(set_def)

    val = set_def['val']
    name = 'in_' + set_def['in']
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
    else
      puts 'wtf is this? ' + node.inspect
      exit(1)
    end
  end
end

logic = YAML.load(IO.read(ARGV[0]))
puts PipelineEngineer.new.construct(logic).to_yaml

