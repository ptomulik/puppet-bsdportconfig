module Puppet
  newtype(:bsdportconfig) do
    @doc = 'Ensures that certain build options are set (or unset) for a given
    BSD port.'

    newproperty(:ensure) do
      desc 'Ensure that port configuration is synchronized with options.
      Accepts values: insync. Defaults to \'insync\'.'

      defaultto :insync

      newvalue(:insync) do
        provider.apply_options
      end

      def retrieve
        provider.altered_options.empty? ? :insync : :outofsync
      end
    end

    newparam(:name) do
      desc 'The package name. It has the same meaning as the $name parameter to
      the package resource from core puppet.'
    end

    newparam(:options) do
      desc 'Options for the package. This is a hash with keys being option
      names and values being on/off strings'
      defaultto Hash.new
      validate do |opts|
        unless opts.is_a? Hash
          fail ArgumentError, "The 'options' parameter must be a hash." + \
            "Got an instance of #{ops.class} class."
        end
        opts.each do |k, v|
          unless v.is_a? String
            fail ArgumentError, "Invalid value type #{v.class} for option #{k}"
          end
          unless v =~ /^(on|off)$/
            fail ArgumentError, "Invalid value #{v} for option #{k}"
          end
        end
      end
    end

    newparam(:portsdir) do
      desc 'Location of the ports tree. This is /usr/ports on FreeBSD and
      OpenBSD, and /usr/pkgsrc on NetBSD.'
      validate do |value|
        unless Puppet::Util.absolute_path?(value)
          fail ArgumentError, "The portsdir parameter must be an absolute path.
          not #{value}"
        end
      end

      defaultto do
        case Facter.value(:operatingsystem)
        when /FreeBSD/, /OpenBSD/
          '/usr/ports'
        when /NetBSD/
          '/usr/pkgsrc'
        else
          nil
        end
      end
    end

    newparam(:port_dbdir) do
      desc 'Directory where the result of configuring options are stored.
      Defaults to /var/db/ports.'

      validate do |value|
        unless Puppet::Util.absolute_path?(value)
          fail ArgumentError, "The port_dbdir parameter must be an absolute path.
          not #{value}"
        end
      end

      defaultto '/var/db/ports'
    end

  end
end
