# bsdportconfig

Configure build options for FreeBSD ports.

Source code is available at: [https://github.com/ptomulik/puppet-bsdportconfig](https://github.com/ptomulik/puppet-bsdportconfig)

#### Table of Contents

1. [Overview](#overview)
2. [Module Description](#module-description)
3. [Setup](#setup)
    * [What Bsdportconfig affects](#what-bsdportconfig-affects)
    * [Setup requirements](#setup-requirements)
    * [Beginning with Bsdportconfig](#beginning-with-bsdportconfig)
4. [Usage](#usage)
5. [Limitations](#limitations)
6. [Development](#development)

## Overview

This module implements a **bsdportconfig** resource to ensure that certain
build options are set (or unset) for a BSD port.

## Module Description

The **bsdportconfig** module helps to configure BSD ports.

Installation and de-installation of FreeBSD ports is handled quite well by
`package` resource from **puppet**'s core. However, it has no way to
set configuration options for ports (no `make config` stage), and always
installs packages with their default options (or with manually pre-set
options).

This module tries to fill this gap. It helps to ensure, that certain
configuration options are set (or unset) for certain ports. You may chain the
**bsdportconfig** resource with **package** to achieve automatic configuration
of ports before they get installed.

The module supports only the **on/off** options.

## Setup

### What Bsdportconfig affects

This module affects:

* config options for given ports, it's done by modifying options files
  `$port_dbdir/*/options`, where `$port_dbdir='/var/db/ports'` by default.

### Setup Requirements

You may need to enable **pluginsync** in your *puppet.conf*.
	
### Beginning with Bsdportconfig	

**Note**: the resource modifies only the options listed in `options`
parameter. Other options are left unaltered (even if they currently differ from
their default values defined by port's Makefile).


**Example**: ensure that `www/apache22` is configured with `SUEXEC` and `CGID`
modules:

    bsdportconfig {'www/apache22': options => { 'SUEXEC'=>on, 'CGID'=>on } }

**Example**: ensure that `www/apache22` is configured without `CGID` module:

    bsdportconfig {'www/apache22': options => { 'CGID'=>off } }

**Example**: install `www/apache22` package with `SUEXEC` module enabled:

    bsdportconfig {'www/apache22': options => { 'SUEXEC'=>on } }
    package { 'www/apache22': require => Bsdportconfig['www/apache22'] }

## Usage

### Resource type: `bsdportconfig`

#### Parameters within `bsdportconfig`:

##### `ensure` (optional)

Ensure that port configuration is synchronized with the resource. Accepts
value: `insync`. Defaults to `insync`. 

##### `name` (required)

The package name. It has the same meaning and syntax as the `$name` parameter
to the **package** resource from core puppet (for the **ports** provider).

##### `options` (optional)

Options for the package. This is a hash with keys being option names
(uppercase) and values being `'on'`/`'off`' strings. Defaults to empty hash.

##### `portsdir` (optional)

Location of the ports tree (absolute path). Defaults to */usr/ports* on FreeBSD
and OpenBSD, and to */usr/pkgsrc* on NetBSD. 

##### `port_dbdir` (optional)

Directory where the result of configuring options are stored. Defaults to
*/var/db/ports*.

## Limitations

Currently tested on FreeBSD only (NetBSD, OpenBSD haven't been tried - any
feedback welcome). No tests for the provider yet.

## Development

Project is held on GitHub:

[https://github.com/ptomulik/puppet-bsdportconfig](https://github.com/ptomulik/puppet-bsdportconfig)

Feel free to submit issue reports to issue tracker or create pull requests.
