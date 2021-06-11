require 'spec_helper'

require Cuboid::Options.paths.lib + 'rpc/server/output'

class RPCOutput
    include Cuboid::UI::Output
end

describe Cuboid::UI::Output do

    subject { RPCOutput.new }
    let(:message) { 'This is a msg!' }
    let(:logfile ) do
        Cuboid::Options.paths.logs + "output_spec_#{Process.pid}.log"
    end
    let(:exception) do
        e = Exception.new( 'Stuff' )
        e.set_backtrace( [ 'backtrace line1', 'backtrace line2' ] )
        s
    end

    context 'when rerouting messages to a logfile' do
        before( :each ) do
            subject.reroute_to_file( logfile )
        end

        it 'sends output to the logfile' do
            subject.print_line( 'blah' )
            expect(IO.read( logfile ).split( "\n" ).size).to eq(1)
        end
    end
end
