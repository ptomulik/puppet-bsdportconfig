dir = File.expand_path(File.join(File.dirname(__FILE__), '../..'))
$LOAD_PATH.unshift(dir) unless $LOAD_PATH.include?(dir)

require 'puppet/util/bsdportconfig'

module Puppet
  newtype(:bsdportconfig) do
    @doc = <<-DOC
Set build options for BSD ports.

TERMINOLOGY

We use the following terminology when referring ports/packages:

  * a string in form `'apache22'` or `'ruby'` is referred to as *portname*
  * a string in form `'apache22-2.2.25'` or `'ruby-1.8.7.371,1'` is referred to
    as a *pkgname*
  * a string in form `'www/apache22'` or `'lang/ruby18'` is referred to as a
    port *origin*

See http://www.freebsd.org/doc/en/books/porters-handbook/makefile-naming.html

Port *origins* are used as primary identifiers for bsdportconfig instances.
It's recommended to use *origins* or *pkgnames* to identify ports.

AMBIGUITY OF PORTNAMES

Accepting *portnames* (e.g. `apache22`) as the [name](#name-required)
parameter was introduced for convenience in 0.2.0. However, *portnames* in
this form are ambiguous, meaning that port search may find multiple ports
matching the given *portname*. For example `'ruby'` package has three ports
at the time of this writing  (2013-08-30): `ruby-1.8.7.371,1`,
`ruby-1.9.3.448,1`, and `ruby-2.0.0.195_1,1` with origins `lang/ruby18`,
`lang/ruby19` and `lang/ruby20` respectively. If you pass a portname which
matches multiple ports, transaction will fail with a message such as:

    Error: Could not prefetch bsdportconfig provider 'ports': found 3 ports with name 'ruby': 'lang/ruby18', 'lang/ruby19', 'lang/ruby20'
DOC
    newparam(:name) do

      desc "Reference to a port. A *portname*, *pkgname* name or *origin* may
      be passed as the `name` parameter (see TERMINOLOGY in resource
      description).  If the name has form 'category/subdir' it is treated as an
      *origin*. Otherwise, the provider tries to find matching port by
      *pkgname* and if it fails, by *portname*. Note, that *portname*s are
      ambiguous, see AMBIGUITY OF PORTNAMES in the resource description."

      validate do |name|
        regexps = [ /^#{Puppet::Util::Bsdportconfig::PORTORIGIN_RE}$/,
                    /^#{Puppet::Util::Bsdportconfig::PKGNAME_RE}$/,
                    /^#{Puppet::Util::Bsdportconfig::PORTNAME_RE}$/ ]
        unless regexps.any? {|re| name =~ re }
          fail ArgumentError, "#{name.inspect} is ill-formed (for $name)"
        end
      end
    end

    newproperty(:options) do

      desc "Options for the package. This is a hash with keys being option
      names and values being 'on'/'off' strings"

      defaultto Hash.new
      validate do |opts|
        unless opts.is_a? Hash
          fail ArgumentError, "#{opts.inspect} is not a hash (for $options)"
        end
        opts.each do |k, v|
          unless v.is_a?(String)
            fail ArgumentError, "#{v.inspect} is not a string (for $options['#{k}'])"
          end
          unless v =~ /^(on|off)$/
            fail ArgumentError, "#{v.inspect} is not allowed (for $options['#{k}'])"
          end
        end
      end

      def insync?(is)
        return false unless should.is_a?(Hash) and is.is_a?(Hash)
        is.select {|k,v| should.keys.include? k} == should
      end

      def should_to_s(newvalue)
        if newvalue.is_a?(Hash)
          s = Hash[newvalue.sort].inspect
        else
          s = newvalue.inspect
        end
        s
      end

      def is_to_s(currentvalue)
        if currentvalue.is_a?(Hash)
          s = Hash[currentvalue.select{|k,v| should.keys.include? k}.sort].inspect
        else
          s = currentvalue.inspect
        end
        s
      end

    end

  end
end
