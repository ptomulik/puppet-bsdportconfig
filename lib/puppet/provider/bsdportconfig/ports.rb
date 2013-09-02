dir = File.expand_path(File.join(File.dirname(__FILE__), '../../..'))
$LOAD_PATH.unshift(dir) unless $LOAD_PATH.include?(dir)

Puppet::Type.type(:bsdportconfig).provide :ports do

  desc "Default (and the only) provider. Support on FreeBSD, OpenBSD, NetBSD"

  commands :make => '/usr/bin/make'
  confine  :operatingsystem => [ :freebsd, :openbsd, :netbsd ]
  defaultfor :operatingsystem => [ :freebsd, :openbsd, :netbsd ]

  class << self

    require 'puppet/util/bsdportconfig'
    include Puppet::Util::Bsdportconfig

    PROPERTY_HASH_GETTERS = [:options_file, :origin, :package, :pkgname] 

    def mk_property_hash_getters
      PROPERTY_HASH_GETTERS.each do |key|
        define_method(key) do
          @property_hash[key]
        end
      end
    end

  end # << self

  def self.portsdir
    unless @portsdir
      unless (@portsdir = ENV['PORTSDIR'])
        os =  Facter.value(:operatingsystem)
        @portsdir = (os == "NetBSD") ? '/usr/pkgsrc' : '/usr/ports'
      end
    end
    @portsdir
  end

  def self.port_dbdir
    unless @port_dbdir
      unless (@port_dbdir = ENV['PORT_DBDIR'])
        @port_dbdir = '/var/db/ports'
      end
    end
    @port_dbdir
  end

  def self.instances
    hashes = prefetch_property_hashes_with_options(portsdir, port_dbdir)
    hashes.map{|key,hash| new(hash) }
  end

  def self.prefetch(resources)
    hashes = prefetch_property_hashes(resources.keys, portsdir, port_dbdir)
    hashes.each do |key, hash|
      resources[key].provider = new(hash)
    end
  end

  mk_resource_methods
  mk_property_hash_getters

  def flush
    self.class.save_options(options_file, options, pkgname)
    @property_hash.clear
  end

end
