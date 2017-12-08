Name:          swift-OctopusBox
Version:       %{__version}
Release:       %{!?__release:1}%{?__release}%{?dist}
Summary:       Client for Octopus/box in-memory key/value storage

Group:         Development/Libraries
License:       MIT
URL:           https://github.com/my-mail-ru/%{name}
Source0:       https://github.com/my-mail-ru/%{name}/archive/%{version}.tar.gz#/%{name}-%{version}.tar.gz
BuildRoot:     %(mktemp -ud %{_tmppath}/%{name}-%{version}-%{release}-XXXXXX)

BuildRequires: swift >= 4
BuildRequires: swift-packaging >= 0.9
BuildRequires: swiftpm(https://github.com/my-mail-ru/swift-BinaryEncoding.git) >= 0.2.1
BuildRequires: swiftpm(https://github.com/my-mail-ru/swift-IProto.git) >= 0.1.8
BuildRequires: swiftpm(https://github.com/my-mail-ru/swift-Octopus.git) >= 0.1.4

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


%package devel
Summary:  Client for Octopus/box in-memory key/value storage
Requires: %{name} = %{version}-%{release}

%description devel
This package contains client for Octopus/box in-memory key/value storage.
The client implements active record pattern and supports automagical encoding/decoding of tuples into structs using reflection.

%{?__revision:Built from revision %{__revision}.}


%files devel
%defattr(-,root,root,-)
%{swift_moduledir}/*.swiftmodule
%{swift_moduledir}/*.swiftdoc
