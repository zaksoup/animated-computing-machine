#!/bin/ruby

require 'yaml'

# logic = YAML.load(IO.read(ARGV[0]))

# puts logic

# arg1 = logic['print'][0]
# arg2 = logic['print'][1]
# arg3 = logic['print'][2]

# def print_ans(bit1, bit2, bit3)

# end

# print_ans(eval_logic(arg1), eval_logic(arg2), eval_logic(arg3))

all_jobs = []

# - xor: [in2y, in2x]
def eval_xor(gate)

  arg0 = gate[:xor][0]
  arg1 = gate[:xor][1]

  arg0_name = eval_set(arg0)
  arg1_name = eval_set(arg1)

  name = ['xor_', arg0_name, arg1_name].join
  res_name = name + '_res_out'

  build = {
    name: name,
    plan: [
      {
        aggregate: [],
      },
      {
        task: 'xor',
        file: 'animated-computing-machine/gates/xor.yml',
      },
      {
        put: 'out',
        resource: res_name,
        params: {file: 'out/bit'},
      }
    ]
  }

  res_name
end

# def rand_id

# end

# def write_jobs_recursive(job)

# end

Job = Struct.new :output_resource_name, :definition

# set_in1x = Struct.new 'in1x', {}
# set_in1y = Struct.new 'in1y', {}

# root = eval_or({'xor': [set_in1x, set_in1y])

def eval_set(set_def)

  arg0 = gate[:xor][0]
  arg1 = gate[:xor][1]

  res_name = 'in_' + set_def[:in]

  build = {
    name: 'xor1' + rand_id,
    plan: [
      {
        aggregate: [],
      },
      {
        task: 'xor',
        file: 'animated-computing-machine/gates/xor.yml',
      },
      {
        put: 'out',
        resource: res_name,
        params: {file: 'out/bit'},
      }
    ]
  }

  #Job.new res_name, build
  res_name
end

puts eval_set({in: '1x', val: '0'})
puts eval_xor({xor: [{in: '1x', val: '0'}, {in: '1y', val: '0'}]})
puts all_jobs.inspect


