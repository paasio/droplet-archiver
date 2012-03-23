# Droplet Archiver

The Droplet Archiver is a simple Node.JS based application that can be used as
a central storage point for droplet packages within
[Cloud Foundry](http://github.com/cloudfoundry/vcap).

In a stock Cloud Foundry application, droplets are stored and handled by the
Cloud Controller, however this role can be more storage intensive over time
and the built in mechanisms don't allow for replication of application bits.

At PaaS.io, we've been working on breaking up the Cloud Controller into multiple
components, one of which is the droplet archiver.

## Features

* Simple and lightweight process
* Optimized for concurrency and stream
* Self-replicates droplets to other configured nodes

## Configuration

The configuration is a simple JSON file named `config.json`:

```json
{
  "port" : 3000,
  "droplet_path" : "./droplets",
  "credentials" : {
    "username" : "user",
    "password" : "pass"
  },
  "sync_hosts" : [ "127.0.0.1:3000", "127.0.0.1:4000" ]
}
```

The configuration is pretty much self explanitory.  The `sync_hosts` is an
array of other `host:port` servers that should have droplets replicated to. It
is ok to put its self in the list, as it will recognize it already has the
droplet and continue on.

## Usage within Cloud Foundry

This is mainly TBD at this point. The Cloud Controller needs to be updated in
a few places, mainly in `app/models/app_manager.rb` in `new_message` and
`download_app_uri`, as well as `app/controllers/staging_controller.rb` in
`upload_droplet_uri`.

## Endpoints

The application responds to three simple endpoints:

* `GET /droplets/:appid/:sha1` - Download a droplet
* `POST /droplets/:appid/:sha1` - Upload a droplet
* `POST /sync/:appid/:sha1` - Used internally to sync droplets between nodes

Whenever a droplet is uploaded, the file will be validated against the SHA1
given and will be deleted if it doesn't match.

## Replication

Droplets are lazily replicated between other hosts after they are uploaded.
This is done after the request is already responded to.  It uses a separate
endpoint as a simple means to ensure a replication storm isn't created. If a
host already has the specified droplet, it will simply return.  With this,
a node can have itself in the `sync_hosts` list and be ok. It will make a
request to iself, but will just quickly return.

Currently, if it fails to replicate to a node it will just continue on.  It
has no reconciling function to come back, or to ensure consistency across all
nodes. This will be coming soon.

## License / Copyright

The code is released under the Apache 2.0 license. See LICENSE for more details.
Copyright 2012 PaaS.io, Inc.
