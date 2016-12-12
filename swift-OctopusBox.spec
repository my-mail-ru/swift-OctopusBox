Name:          swift-OctopusBox
Version:       %{__version}
Release:       %{!?__release:1}%{?__release}%{?dist}
Summary:       Client for Octopus/box in-memory key/value storage

Group:         Development/Libraries
License:       MIT
URL:           https://github.com/my-mail-ru/%{name}
Source0:       https://github.com/my-mail-ru/%{name}/archive/%{version}.tar.gz#/%{name}-%{version}.tar.gz
BuildRoot:     %(mktemp -ud %{_tmppath}/%{name}-%{version}-%{release}-XXXXXX)

BuildRequires: swift
BuildRequires: swift-packaging
BuildRequires: swift-IProto
BuildRequires: swift-Octopus

%swift_find_provides_and_requires

%description
This package contains client for Octopus/box in-memory key/value storage.
The client implements active record pattern and supports automagical encoding/decoding of tuples into structs using reflection.

%{?__revision:Built from revision %{__revision}.}


%prep
%setup -q
%swift_patch_package


%build
%swift_build


%install
rm -rf %{buildroot}
%swift_install
%swift_install_devel


%clean
rm -rf %{buildroot}


%files
%defattr(-,root,root,-)
%{swift_libdir}/*.so
%{swift_moduledir}/*.swiftmodule
%{swift_moduledir}/*.swiftdoc
