require 'spec_helper'

describe Puppet::Type.type(:bsdportconfig) do

  it "should have a 'name' parameter" do
    Puppet::Type.type(:bsdportconfig).new(:name => 'www/apache22')['name'].should == 'www/apache22'
  end
  it "should have an :ensure property" do
    Puppet::Type.type(:bsdportconfig).attrtype(:ensure).should == :property
  end
  it "should have an :options param" do
    Puppet::Type.type(:bsdportconfig).attrtype(:options).should == :param
  end
  it "should have a :portsdir param" do
    Puppet::Type.type(:bsdportconfig).attrtype(:portsdir).should == :param
  end
  it "should have a :port_dbdir param" do
    Puppet::Type.type(:bsdportconfig).attrtype(:port_dbdir).should == :param
  end

  describe "when validating attribute values" do
    it "should suport :insync as a value to :ensure" do
      Puppet::Type.type(:bsdportconfig).new(:name => 'www/apache22', :ensure => :insync)
    end
    it "should raise Puppet::ResourceError when :ensure is :outofsync" do
      lambda { Puppet::Type.type(:bsdportconfig).new(:name => 'www/apache22', :ensure => :outofsync) }.should( raise_error(Puppet::ResourceError) )
    end
    it "should accept empty hash as a value to :options" do
      Puppet::Type.type(:bsdportconfig).new(:name => 'www/apache22', :options => {})
    end
    it "should raise Puppet::ResourceError when :options is not a hash" do
      lambda { Puppet::Type.type(:bsdportconfig).new(:name => 'www/apache22', :options => 1) }.should( raise_error(Puppet::ResourceError) )
    end
    it "should accept {'A' => 'on'} as a value to :options" do
      Puppet::Type.type(:bsdportconfig).new(:name => 'www/apache22', :options => {'A' => 'on'})
    end
    it "should accept {'A' => 'off'} as a value to :options" do
      Puppet::Type.type(:bsdportconfig).new(:name => 'www/apache22', :options => {'A' => 'off'})
    end
    it "should raise Puppet::ResourceError when :options contains invalid value" do
      lambda { Puppet::Type.type(:bsdportconfig).new(:name => 'www/apache22', :options => {'A' => 'foo'}) }.should( raise_error(Puppet::ResourceError) )
      lambda { Puppet::Type.type(:bsdportconfig).new(:name => 'www/apache22', :options => {'A' => 'once'}) }.should( raise_error(Puppet::ResourceError) )
      lambda { Puppet::Type.type(:bsdportconfig).new(:name => 'www/apache22', :options => {'A' => 'offset'}) }.should( raise_error(Puppet::ResourceError) )
    end
    it "should raise Puppet::ResourceError if :portsdir is not an absolute path" do
      lambda { Puppet::Type.type(:bsdportconfig).new(:name => 'www/apache22', :portsdir => 'foobar') }.should( raise_error(Puppet::ResourceError) )
    end
    it "should raise Puppet::ResourceError if :port_dbdir is not an absolute path" do
      lambda { Puppet::Type.type(:bsdportconfig).new(:name => 'www/apache22', :port_dbdir => 'foobar') }.should( raise_error(Puppet::ResourceError) )
    end
  end

end
