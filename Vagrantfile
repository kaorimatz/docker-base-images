Vagrant.configure('2') do |config|

  config.vm.box = 'kaorimatz/fedora-rawhide-x86_64'

  config.vm.define 'docker-base-images' do |c|
    config.vm.provider :virtualbox do |v|
      v.name = 'docker-base-images'
    end
  end

  config.vm.provision :shell do |sh|
    sh.inline = <<-EOS
    dnf -y install docker-io MAKEDEV yum pacman
    systemctl enable docker
    systemctl start docker
    EOS
  end

end
