FROM registry.access.redhat.com/rhel6.8
MAINTAINER Rafael Pires "rafael.pires@xxx.co.uk"

ENV  REFRESHED_ON  20170320
ENV BUNDLE_GEMFILE=/root/Gemfile

ARG ruby_version
ARG gemset_name

COPY root/ /root/
COPY Gemfile /root/

RUN yum -y install tar which rpm-build facter
RUN yum-config-manager --enable rhel-server-rhscl-6-rpms --enable rhel-6-server-optional-rpms
RUN curl -sSL https://get.rvm.io | bash
RUN /bin/bash -l -c "rvm install $ruby_version"
RUN /bin/bash -l -c "rvm gemset create $gemset_name"
RUN /bin/bash -l -c "rvm $ruby_version@$gemset_name do gem install bundler --no-ri --no-rdoc"
RUN /bin/bash -l -c "bundle install"

# install satellite5 tools
RUN yum-config-manager --enable rhel-6-server-rhn-tools-rpms
RUN yum -y install rhnpush

RUN mkdir /package-builder /package-builder/output
COPY Rakefile /package-builder
COPY lib/ /package-builder/lib/

WORKDIR /package-builder

CMD [ "/bin/bash" ]