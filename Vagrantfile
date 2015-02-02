Vagrant.configure('2') do |config|

  config.vm.box = 'kaorimatz/fedora-rawhide-x86_64'

  config.vm.provider :virtualbox do |vbox|
    vbox.name = 'docker-base-images'
  end

  config.vm.provision :shell do |sh|
    sh.inline = <<-EOS
    dnf -y install docker-io MAKEDEV yum
    systemctl enable docker
    EOS
  end

end
