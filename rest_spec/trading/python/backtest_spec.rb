# coding: utf-8

require 'client'
require 'uri'

describe '/backtest' do
  before(:example) do
    @client = Jiji::Client.instance
    @data_builder = Jiji::Test::DataBuilder.new
  end

  it '`POST /backtests` can register and execute a backtest' do

    r = @client.post('agents/sources', {
      name: 'python_test1',
      memo: 'メモ1',
      type: :agent,
      language: 'python',
      body: @data_builder.new_python_agent_body
    })
    expect(r.status).to eq 201

    r = @client.post('backtests', {
      'name'             => 'テスト',
      'start_time'       => Time.utc(2015, 6, 2),
      'end_time'         => Time.utc(2015, 6, 3),
      'memo'             => 'メモ',
      'pair_names'       => [:EURJPY, :EURUSD],
      'tick_interval_id' => 'one_hour',
      'balance'          => 1_000_000,
      'agent_setting'    => [
        {
          agent_class: 'TestAgent@python_test1',
          agent_name:  'テスト1',
          properties:  { 'a' => 1, 'b' => 'bb' }
        }
      ]
    })
    expect(r.status).to eq 201

    expect(r.body['name']).to eq 'テスト'
    expect(r.body['id']).not_to be nil
    expect(r.body['created_at']).not_to be nil
    test_id = r.body['id']

    wait_for_the_end_of_backtest(test_id)
    logs = retrieve_log(test_id)
    expect(logs.find {|l| l =~ /WARN \-\- \: tick\:1\.1234 1\.1236/}).not_to be nil
    expect(logs.find {|l| l =~ /WARN \-\- \: tick\:1\.3834 1\.3836/}).not_to be nil
    expect(logs.find {|l| l =~ /INFO \-\- \: properties\:1_bb/}).not_to be nil
  end

  def retrieve_log(id)
    r = @client.get("logs/#{id}",  {
      'index' => 0
    })
    return r.body['body'].split(/\n/)
  end

  def wait_for_the_end_of_backtest(test_id)
    loop do
      r = @client.get('backtests', { 'ids' => test_id.to_s })
      status = r.body[0]['status']
      return if status == 'finished' || status == 'error'
      sleep 2
    end
  end

end