require 'rspec'
require_relative 'gen.rb'

describe 'eval_set' do
  it 'has a name' do
    job = eval_set({in: '1x', val: '0'})
    expect(job.output_resource_name).to eq('in_1x')
  end

  it 'has a definition' do
    job = eval_set({in: '1x', val: '0'})
    expect(job.definition[:name]).to be_a(String)
    expect(job.definition[:plan]).to be_a(Array)
    expect(job.definition[:plan][1][:config][:run][:args][1]).to contain('"1" > out/bit')
    expect(job.definition[:plan][2][:put]).to be_a(Hash)
  end
end
