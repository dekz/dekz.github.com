---
layout: post
title: Simple Docker DNS
tag: hack docker hooroo
published: false
---

So I'm guessing you're like me, you're eager to hack on new tech, keen to understand how things work and much prefer simplicity. Great, I'm like me too.

I wanted to run some services in containers. These services were linked together but they really didn't know a whole lot about each other. Sure they have the `docker` links and environment variables like `TCP_1234_ADDR_PORT_HOST`. Sure, I could resolve that ENV variable and find the host, but that doesn't help me with GUI configs for services that I have no control over. And it doesn't help link my host up to the containers running.

My goal was to hack something simple and reasonable. A way to connect the containers together and my dev machine to the containers.

If you want to cut to the chase, then here is the final [repo](https://github.com/dekz/docker-dns).

## DNS Container

My plan was to see if I could use a docker container as a DNS resolver, then hook it up to other containers, then hook it up to my OSX machine. To achieve this the plan was to create a number of things:

1. Docker container for the dns resolver
2. Watch for containers and update dns records for the resolver
3. Hook up the containers and my host machine

Let's start with a pretty basic `Dockerfile`, then use `dnsmasq` as our DNS resolver and finally a special program: `docker-gen`.

### Dockerfile
{% render_gist https://gist.githubusercontent.com/dekz/1fef9cc8cfba39c22219/raw/13f0c99b0b32a67a419f2ee92c848b14bd6aa719/Dockerfile bash %}

[docker-gen](https://github.com/jwilder/docker-gen/) is a utility by jwilder that hits the Docker api and renders templates based off that meta-data. We can use `docker-gen` to render `dnsmasq` config file everytime a docker container is born.

It uses the go text templating language, here is what my `dnsmasq.tmpl` template file looks like:

### dnsmasq.tmpl
{% render_gist https://gist.githubusercontent.com/dekz/3e37d5aa399e7a7680f5/raw/dnsmasq.tmpl bash %}

This script iterates through all the hosts and if it has an address then entries DNS is set to be the containers `VIRTUAL_HOST` environment variable and resolved it to the ip address of the container. As you can see it uses the `.jacob` TLD.

That `restart` command for `docker-gen` and `dnsmasq` is nothing more than restarting dnsmasq:

### restart
{% highlight bash %}
killall dnsmasq
dnsmasq
{% endhighlight %}

I prefer to use [fig](http://fig.sh) to manage the runtime lifecycle of docker containers, it makes my life easier and yours to.

### fig.yml
{% highlight yaml %}
dns:
  build: .
  command: docker-gen -interval 10 -watch -notify "sh /app/restart" dnsmasq.tmpl /etc/dnsmasq.conf
  environment:
    DOCKER_HOST: unix:///var/run/docker.sock
    VIRTUAL_HOST: dns-guy
  privileged: true
  volumes:
    - /var/run/docker.sock:/var/run/docker.sock
  ports:
    - "53:53/udp"
{% endhighlight %}

The dns container `COMMAND` runs docker-gen which constantly pings the docker api, upon noticing a change it then renders `dnsmasq.tmpl` to `/etc/dnsmasq.conf` and notifies the container by running `restart`.  

We `volume` mount in the parent docker socket to get access to the API and tell `docker-gen` how to find docker with `DOCKER_HOST`. Finally, we open the port `53` on the host and map that to `53` inside the container (dnsmasq) for udp. This requires `priveleged` since the port value is so low.  

FINALLY finally, let's set `VIRTUAL_HOST` to some value so we can test that we resolve ourselves.

Now some magic happens round about here, containers use their host for some dns resolution. So since we hijacked `53/udp` the request teleports from the dns container, back into the dns container.

This means, every subsequent container should also be able to magically just work.

### fig.yml for our app
{% highlight yaml %}
app:
  image: ubuntu:trusty
  command: sleep 9000
  environment:
    VIRTUAL_HOST: test-dns-yes-yes
  ports:
    - "8080"
{% endhighlight %}

`VIRTUAL_HOST` is the only environment variable we need to set, this will allow the dns to eb resolved. It should work just like magic.

# OSX Setup
Now the real meat of it, it's all well and good if I can get the containers finding each other, docker could already kind of support that. Let's pipe the functionality into OSX so my local dev machine will resolve `.jacob` TLD to the dns container. Firstly, we need to tell OSX to route anything on the docker subnet into the boot2docker vm. This will need to happen every reboot as the table is trashed.

    sudo route -n add 172.17.0.0/16 `boot2docker ip`

Secondly we will use OSX resolver and create an entry just for `.jacob`

    sudo echo "nameserver `boot2docker ip`" > /etc/resolver/jacob

Now see if you can ping `dns-guy.jacob` from your OSX machine.


# Demo
<script type="text/javascript" src="https://asciinema.org/a/14341.js" id="asciicast-14341" async></script>
