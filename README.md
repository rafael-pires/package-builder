## Building packages


### Introduction

The procedure listed in this page is intended to automate and standardize how internal packages are stored, built and managed by XXX. Ruby Rake is used for building and bundling software into RPM package format. Packaging is performed by fpm.

Docker images are used so the process can build packages for different versions of RedHat and different distributions if needed. All the code is stored in pakage-builder repository in gitlab (ldsrvpptgitp001.ladsys.net:Others/package-builder.git).

Any new package definitions should be stored in their own gitlab repositories in the Packages namespace group, such as Packages/xxx-openbet.


Building binaries from source is not supported yet.


### Diagram of the solution

<draft>

push to gitlab repository under Packages namespace group git push hook jenkins package_builder job docker-compose up pkgbld rake tasks (qureySatellite, buildRpm, uploadToSatellite)

</draft>


### Creating a new package

In summary this is the process to build a new package:

1. Create a new repo in Packages namespace in gitlab where the new package definitions will be stored.

2. Add a web hook for push events to trigger the jenkins job (http://jenkins-dev.ladsys.net:8080/gitlab/build_now/package-builder)

3. The repo requires to have a pkg definition file (package.json) and the package contents should be under the input directory.

4. Push the repo, this will trigger the jenkins job which should execute the rake tasks and build and push the new package to satellite.

Look into xxx-openbet repository for an example on what options are available to build a new package ldsrvpptgitp001.ladsys.net:Packages xxx-openbet.git




Testing/troubleshooting package builder locally

If desired, the new package can be built locally to test/validate the result prior to pusing to a git repo as described below:


1- Ensure docker and docker-compose are installed in your pc (the docker-compose is not required but will make things easier). 2- Clone the package-builder repo.

$ git clone git@ldsrvpptgitp001.ladsys.net:Others/package-builder.git

3- Move inside the package-builder directory and create the directory structure for the new package. $ mkdir xxx-mypkg

4- Export PKGNAME variable.

$ export PKGNAME=xxx-mypkg


5-
a) If you are feeling lucky and believe the package will be built successfully without any issues (most issues are caused by syntax error in package.json so you should check for syntax and lint it), then: $ docker-compose up

b) If you want to be more cautious, then build the docker image first, then run bash in the container and execute each rake task one after the other:

$ docker-compose build

$ docker-compose run pkgbld bash

once inside the container:

$ rake -T

$ rake buildRpm

If fpm fails and you need to troubleshoot then you can run the buildRpm with keep_tmp_dir flag so it will keep temporary directory and you can copy/paste the fpm command and may get more info on why failed to build.


6- Once happy create a new git repo for the new package and push from the local directory.


Example:

rpires@workstation [ dev ~/Documents/git/package-builder ]$ export PKGNAME=xxx-elkes rpires@workstation [ dev ~/Documents/git/package-builder ]$ docker-compose build

Building pkgbld

Step 1 : FROM registry.access.redhat.com/rhel6.8

---> add32b97a8cb

Step 2 : MAINTAINER Rafael Pires "rafael.pires@xxx.co.uk"

---> Using cache

---> 53bc651de735

Step 3 : ENV REFRESHED_ON 20170207

---> Using cache

---> 6d79f9baf2d2

Step 4 : ENV BUNDLE_GEMFILE /root/Gemfile

---> Using cache

---> b20b1d861f8f

Step 5 : ARG ruby_version

---> Using cache

---> 3f48460bd370

Step 6 : ARG gemset_name

---> Using cache

---> 72e74a581f0c

Step 7 : COPY root/ /root/

---> Using cache

---> 77149dc37c0f

Step 8 : COPY Gemfile /root/

---> Using cache

---> 41eea1df531b

Step 9 : RUN yum -y install tar which rpm-build facter

---> Using cache

---> c586a07a6998

Step 10 : RUN yum-config-manager --enable rhel-server-rhscl-6-rpms --enable rhel-6-server-optional-rpms

---> Using cache

---> 83fbcc4d3b92

Step 11 : RUN curl -sSL https://get.rvm.io | bash

---> Using cache

---> 4034ed07d482

Step 12 : RUN /bin/bash -l -c "rvm install $ruby_version"

---> Using cache

---> 2e36b1bd462a

Step 13 : RUN /bin/bash -l -c "rvm gemset create $gemset_name"

---> Using cache

---> 62951ad0042c

Step 14 : RUN /bin/bash -l -c "rvm $ruby_version@$gemset_name do gem install bundler --no-ri --no-rdoc"

---> Using cache

---> 9fb96cce6e7e

Step 15 : RUN /bin/bash -l -c "bundle install"

---> Using cache

---> df788fd53bf9

Step 16 : RUN yum-config-manager --enable rhel-6-server-rhn-tools-rpms
---> Using cache

---> b8680e26ffaf

Step 17 : RUN yum -y install rhnpush

---> Using cache

---> b492a4a6e879

Step 18 : RUN mkdir /package-builder /package-builder/output

---> Using cache

---> 7089fda9000d

Step 19 : COPY Rakefile /package-builder

---> Using cache

---> f6c14f9ff818

Step 20 : COPY lib/ /package-builder/lib/

---> Using cache

---> bd65ad7a7326

Step 21 : WORKDIR /package-builder

---> Using cache

---> 05b034b72a6d Step 22 : CMD /bin/bash
---> Using cache

---> 246c8fb0dd56 Successfully built 246c8fb0dd56
rpires@workstation [ dev ~/Documents/git/package-builder ]$ docker-compose run pkgbld bash [root@pkgbld package-builder]# rake -T

rake buildRpm[keep_tmp_file] # Build RPM: xxx-elkes-5.1-1.el6.x86_64.rpm

rake clobber
### Remove any generated file
rake querySatellite
### Check RPM in satellite
rake uploadToSatellite
### Upload RPM in satellite
[root@pkgbld package-builder]# rake clobber
rm -rf output/xxx-elkes-5.1-1.el6.x86_64.rpm
[root@pkgbld package-builder]# rake buildRpm
I, [2017-03-02T10:28:34.266673 #135]
INFO -- : Creating /tmp/tmp.JLZFLH3lok to build rpm.
I, [2017-03-02T10:28:34.269000 #135]
INFO -- : Building RPM 'xxx-elkes-5.1-1.el6.x86_64.rpm'
I, [2017-03-02T10:28:34.269253 #135]
INFO -- : Executing "fpm -s dir -t rpm --architecture x86_64 --name xxx-elkes --after-install

/package-builder/xxx-elkes/input/scripts/post-inst.bash --after-remove /package-builder/xxx-elkes/input/scripts/post-uninst.bash

--before-remove /package-builder/xxx-elkes/input/scripts/pre-uninst.bash --depends 'elk-java' --
description 'Custom xxx
Elasticsearch single node deployment'
--iteration 1 --rpm-compression gzip --
rpm-group elkadmin --package
output/xxx-elkes-5.1-1.el6.x86_64.rpm --
rpm-sign --rpm-user elkadmin --
vendor xxx --
rpm-use-file-permissions --version 5.1
-C /tmp/tmp.JLZFLH3lok/contents ."




I, [2017-03-02T10:28:37.980861 #135]
INFO --
: Created package {:path=>"output/xxx-elkes-5.1-1.el6.x86_64.rpm"}
I, [2017-03-02T10:28:37.980972 #135]
INFO --
: removing /tmp/tmp.JLZFLH3lok

[root@pkgbld package-builder]# $
















Related articles

Building internal packages