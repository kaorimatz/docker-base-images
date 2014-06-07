Vagrant.configure('2') do |config|
  config.vm.box = 'kaorimatz/fedora-rawhide-x86_64'

  config.vm.provider :virtualbox do |v|
    v.name = 'docker-base'
  end

  config.vm.provision :shell do |s|
    s.inline = <<-EOS
    yum -y install docker-io
    systemctl enable docker
    systemctl start docker
    EOS
  end
end
