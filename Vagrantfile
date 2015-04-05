Vagrant.configure('2') do |config|

  config.vm.box = 'kaorimatz/fedora-21-x86_64'

  config.vm.define 'docker-base-images' do |c|
    config.vm.provider :virtualbox do |v|
      v.name = 'docker-base-images'
    end
  end

  config.vm.provision :shell do |sh|
    sh.inline = <<-EOS
    yum -y install docker-io pacman
    systemctl enable docker
    systemctl start docker
    EOS
  end

end
