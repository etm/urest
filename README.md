<img align="right" height="100" src="https://github.com/etm/urest/blob/main/logo/urest_logo.png">

# UREST

A simple REST server for Universal robots in ruby, which uses the ur-sock library.

## Getting Started

A simple ruby server, which uses the ur-sock library.

### Prerequisites & Installation



This server has no special prerequisites. But it is always advisable to prepare
your machine for installation and development, and install some common
libraries and headers, which are used by common dependencies:

    * Windows 10 users with WSL2 can use Fedora/Ubuntu instructions below 
    * Mac OSX users can use brew: brew install libxml2 libxslt 
    * Ubuntu (>=20.04) / Debian users can use their package manager: ```sudo apt-get install build-essential ruby-dev libxml2-dev libxslt-dev libz-dev libssl-dev librasqal-dev libraptor2-dev libicu-dev redis```
    * Fedora (>=32) users can use their package manager: ```sudo dnf install @buildsys-build @development-tools @c-development ruby-devel libxml2-devel libxslt-devel zlib-devel rasqal-devel raptor2-devel libicu-devel redis``` 

You cann the UREST gem with:

```
gem install urest
```

If you want to develop or extend the server, just use the following instruction
```
git clone https://github.com/etm/urua
git clone https://github.com/fpauker/ur-sock
```

Just follow the install instructions of the 2 projects.

### Starting the server

To scaffold a server, first create a directory, then use the urua

```
mkdir -p ~/run/urest
cd ~/run/urest
urest scaffold
```

After changing the \.conf file to point to your UR, you can start the server with

```
./urest start
```

or

```
./urest -v start
```

to see verbose output.

## Contributing

Please read [CONTRIBUTING.md](https://gist.github.com/PurpleBooth/b24679402957c63ec426) for details on our code of conduct, and the process for submitting pull requests to us.

## Versioning

We use [SemVer](http://semver.org/) for versioning.

## Authors

* **Jürgen Mangler**

See also the list of [contributors](https://github.com/etm/urest/AUTHORS) who participated in this project.

## License

This project is licensed under the GPL3 License - see the [LICENSE.md](./LICENSE) file for details
