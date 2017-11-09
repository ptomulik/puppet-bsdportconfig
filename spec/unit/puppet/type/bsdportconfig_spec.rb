require 'spec_helper'

describe Puppet::Type.type(:bsdportconfig) do

  it 'should have $name parameter' do
    Puppet::Type.type(:bsdportconfig).new(:name=>'x')['name'].should == 'x'
  end
  it 'should have $options parameter' do
    Puppet::Type.type(:bsdportconfig).attrtype(:options).should == :property
  end

  describe 'when validating parameters' do
    it "should accept $options={}" do
      Puppet::Type.type(:bsdportconfig).new(:name=>'x', :options=>{})
    end
    it "should fail when $name is ill-formed" do
      msg = /"ill formed" is ill-formed \(for \$name\)/
      lambda {
        Puppet::Type.type(:bsdportconfig).new(:name=>'ill formed', :options=>1)
      }.should( raise_error Puppet::Error, msg )
    end
    [1, 'a', false].each do |options|
      it "should fail when $options=>#{options.inspect}" do
        msg = /#{Regexp.escape(options.inspect)} is not a hash \(for \$options\)/
        lambda {
          Puppet::Type.type(:bsdportconfig).new(:name=>'x', :options=>options)
        }.should( raise_error Puppet::Error, msg )
      end
    end
    ['foo', 'once', 'offset'].each do |v|
      it "should fail when $options=>{'A'=>#{v}}" do
        hash = {:name=>'x', :options=>{'A'=>v}}
        msg = /#{v.inspect} is not allowed \(for \$options\['A'\]\)/
        lambda {
          Puppet::Type.type(:bsdportconfig).new(hash)
        }.should( raise_error Puppet::Error, msg)
      end
    end
    it "should accept $options=>{'A'=>'on'}" do
      Puppet::Type.type(:bsdportconfig).new(:name=>'x', :options=>{'A'=>'on'})
    end
    it "should accept $options=>{'A'=>'off'}" do
      Puppet::Type.type(:bsdportconfig).new(:name=>'x',:options=>{'A'=>'off'})
    end
  end

end
