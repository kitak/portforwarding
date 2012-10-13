#!/usr/bin/env ruby

# Determine the ssh's destination
INTERNAL = "username@internalserver"
EXTERNAL = "username@gatewayserver"
$gateway = EXTERNAL

if File.exist?("/etc/resolv.conf") then
  File.open("/etc/resolv.conf", "r"){|conf|
    while (l = conf.gets) != nil
      # replace 'internaldomain.foo.bar.jp' with your remote domain name
      if /domain\s+internaldomain.foo.bar.jp/=~l then
        $gateway = INTERNAL
      end
    end
  }
end

# Loopback IP duplication for for SMB 
ip_dup = {
  #"name"=>"sudo ifconfig eth0:0 localip up",
  "smb0"=>"sudo ifconfig eth0:0 192.168.100.12 up"
}

# SMB
smb_ports = {
  #"name"=>"ssh -f -N -L localip:localport:remoteip:remoteip GATE",
  "smb0"=>"ssh -f -N -L 192.168.100.12:8139:192.168.0.1:139 GATE",
}

# SSH
ssh_ports = {
  #"name" =>"ssh -f -N -L localport:remoteip:remoteport GATE",
  "ssh0" =>"ssh -f -N -L 2212:192.168.0.2:22 GATE",
}

# WWW,
www_ports = {
  # dynamic port forwarding with SCKET
  "dyn"  =>"ssh -f -N -D 10080 GATE",
  # staic port forwarding
  #"name"  =>"ssh -f -N -L localport:remoteip:remoteport GATE",
  "www0"  =>"ssh -f -N -L 8011:192.168.0.3:80 GATE",
}

USAGE = "\
## Port Forwarding Script written in Ruby
Usage: ruby pf.rb mode port_type
mode
  open   : open a new forwarding port
  close  : close specified forwarding port
  reopen : re-open specified forwarding port 
  status : show current status of opened port forwardings
  list   : show list of all port forwardings
  help   : show this page
port_type
  ssh : 22
  www : 80
  smb : 139
  all : all of ssh, www, smb
"
if ENV['OS'] then
  SSH=/ssh$/
else
#  SSH=/ssh.*\-f \-N \-L/
  SSH=/ssh.*\-f \-N \-L|D/
end

def anyinclude?(pl, value)
  ret = false
  pl.each{|p|
    if p.include?(value) then
      ret = true
    end
  }
  return ret
end

def rp(str)
  return str.sub(/GATE/,$gateway)
end

def dl(str)
  return str.sub(/GATE/,"")
end

if ARGV.length == 0 then
  print USAGE
  exit
end
mode = ARGV[0]

dup_list = Hash::new
list = Hash::new
i = 1
if /^open$/=~mode or /^close$/=~mode or /^reopen$/=~mode or /^re$/=~mode then
  while ARGV[i] != nil 
    if /^all$/=~ARGV[i] then
      ip_dup.each_key{|key|
        if !dup_list.key?('smb.'+key) then
          dup_list['smb.'+key] = ip_dup[key]
        end
      }
      ssh_ports.each_key{|key|
        if !list.key?('ssh.'+key) then
          list['ssh.'+key] = ssh_ports[key]
        end
      }
      smb_ports.each_key{|key|
        if !list.key?('smb.'+key) then
          list['smb.'+key] = smb_ports[key]
        end
      }
      www_ports.each_key{|key|
        if !list.key?('www.'+key) then
          list['www.'+key] = www_ports[key]
        end
      }

    elsif /^ssh$/=~ARGV[i] or /^ssh\.all$/=~ARGV[i] then
      ssh_ports.each_key{|key|
        if !list.key?('ssh.'+key) then
          list['ssh.'+key] = ssh_ports[key]
        end
      }
    elsif /^ssh\.(.+)/=~ARGV[i] then
      if ssh_ports.key?($1) then
        if !list.key?('ssh.'+$1) then
          list['ssh.'+$1] = ssh_ports[$1]
        end
      else
        puts "No such port forwarding rule: ssh.#{$1}"
      end

    elsif /^smb$/=~ARGV[i] or /^smb\.all$/=~ARGV[i] then
      ip_dup.each_key{|key|
        if !dup_list.key?('smb.'+key) then
          dup_list['smb.'+key] = ip_dup[key]
        end
      }
      smb_ports.each_key{|key|
        if !list.key?('smb.'+key) then
          list['smb.'+key] = smb_ports[key]
        end
      }
    elsif /^smb\.(.+)/=~ARGV[i] then
      if ip_dup.key?($1) then
        if !dup_list.key?('smb.'+$1) then
          dup_list['smb.'+$1] = ip_dup[$1]
        end
      else
        puts "No such port forwarding rule: dup.#{$1}"
      end
      if smb_ports.key?($1) then
        if !list.key?('smb.'+$1) then
          list['smb.'+$1] = smb_ports[$1]
        end
      else
        puts "No such port forwarding rule: smb.#{$1}"
      end

    elsif /^www$/=~ARGV[i] or /^www\.all$/=~ARGV[i] then
      www_ports.each_key{|key|
        if !list.key?('www.'+key) then
          list['www.'+key] = www_ports[key]
        end
      }
    elsif /^www\.(.+)/=~ARGV[i] then
      if www_ports.key?($1) then
        if !list.key?('www.'+$1) then
          list['www.'+$1] = www_ports[$1]
        end
      else
        puts "No such port forwarding rule: www.#{$1}"
      end
    else
      puts "No such port forwarding rule: #{ARGV[i]}"
    end
    i = i + 1
  end
elsif /^list$/=~mode or /^ls$/=~mode then
elsif /^status$/=~mode or /^st$/=~mode then
else
  print USAGE
  exit
end

ps_list = []
IO.popen("ps ax", "r+"){|io|
  while (l = io.gets) != nil
    if SSH =~ l  then
      ps_list << l
    end
  end
}

if /^close$/=~mode then
  pf = []  
  list.each_value{|value|
    ps_list.each{|p|
      if p.include?(dl(value)) then
        if /(\d+)/=~ p then
          pf << $1
        end
      end
    }
  }
  pf.each{|ps|
    system("kill -9 #{ps}")
  }
end

if /^open$/=~mode then
  list.delete_if{|key, value|
    anyinclude?(ps_list, dl(value))
  }
  dup_list.each_value{|value|
    system "#{rp(value)}"
  }
  list.each_value{|value|
    system "#{rp(value)}"
  }
end

if /^reopen$/=~mode or /^re$/=~mode then
  pf = []  
  list.each_pair{|key, value|
    if !anyinclude?(ps_list, dl(value)) then
      list.delete(key)
      dup_list.delete(key)
      puts "No such opened port: #{key}"
    end
  }
  list.each_value{|value|
    ps_list.each{|p|
      if p.include?(dl(value)) then
        if /(\d+)/=~ p then
          pf << $1
        end
      end
    }
  }
  pf.each{|ps|
    system("kill -9 #{ps}")
  }
  dup_list.each_value{|value|
    system "#{rp(value)}"
  }
  list.each_value{|value|
    system "#{rp(value)}"
  }
end

if /^list$/=~mode or /^ls$/=~mode then
  puts "[ssh]"
  ssh_ports.each_pair{|key, value|
    puts "ssh.#{key} : #{rp(value)}"
  }
  puts "[smb]"
  smb_ports.each_pair{|key, value|
    puts "smb.#{key} : #{rp(value)}"
  }
  puts "[www]"
  www_ports.each_pair{|key, value|
    puts "www.#{key} : #{rp(value)}"
  }
end

if /^status$/=~mode or /^st$/=~mode then
  puts "[ssh]"
  ssh_ports.each_pair{|key, value|
    if anyinclude?(ps_list, "#{value}") then
      puts "ssh.#{key} : #{value}"
    elsif anyinclude?(ps_list, "#{dl(value)}#{INTERNAL}") then
      puts "ssh.#{key} : #{dl(value)}#{INTERNAL}"
    elsif anyinclude?(ps_list, "#{dl(value)}#{EXTERNAL}") then
      puts "ssh.#{key} : #{dl(value)}#{EXTERNAL}"
    end
  }
  puts "[smb]"
  smb_ports.each_pair{|key, value|
    if anyinclude?(ps_list, "#{value}") then
      puts "smb.#{key} : #{value}"
    elsif anyinclude?(ps_list, "#{dl(value)}#{INTERNAL}") then
      puts "smb.#{key} : #{dl(value)}#{INTERNAL}"
    elsif anyinclude?(ps_list, "#{dl(value)}#{EXTERNAL}") then
      puts "smb.#{key} : #{dl(value)}#{EXTERNAL}"
    end
  }
  puts "[www]"
  www_ports.each_pair{|key, value|
    if anyinclude?(ps_list, "#{value}") then
      puts "www.#{key} : #{value}"
    elsif anyinclude?(ps_list, "#{dl(value)}#{INTERNAL}") then
      puts "www.#{key} : #{dl(value)}#{INTERNAL}"
    elsif anyinclude?(ps_list, "#{dl(value)}#{EXTERNAL}") then
      puts "www.#{key} : #{dl(value)}#{EXTERNAL}"
    end
  }
end
