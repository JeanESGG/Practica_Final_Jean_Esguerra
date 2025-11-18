Vagrant.configure("2") do |config|
  config.vm.define :servidorWeb do |servidorWeb|
    servidorWeb.vm.box = "bento/ubuntu-22.04"
    servidorWeb.vm.network :private_network, ip: "192.168.50.3"
    servidorWeb.vm.hostname = "servidorWeb"
    
    # Recursos de la VM (opcional pero recomendado)
    servidorWeb.vm.provider "virtualbox" do |vb|
      vb.memory = "2048"
      vb.cpus = 2
      vb.name = "ServidorWeb-Prometheus"
    end
    
    # Copiar archivos y carpetas necesarias
    servidorWeb.vm.provision "file", source: "docker-compose.yml", destination: "/home/vagrant/docker-compose.yml"
    servidorWeb.vm.provision "file", source: "webapp", destination: "/home/vagrant/webapp"
    servidorWeb.vm.provision "file", source: "nginx", destination: "/home/vagrant/nginx"
    servidorWeb.vm.provision "file", source: "mysql", destination: "/home/vagrant/mysql"
    
    # Ejecutar script de provisión
    servidorWeb.vm.provision "shell", path: "provision-servidor.sh"
  end
end