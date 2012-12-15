basho_bench_gui
===============

**Installation**

    $ git clone http://github.com/deanproctor/basho_bench_gui
    $ cd basho_bench_gui
    $ sudo ./install_demo.sh

**Configuration**

1. Set web-accessible IP/DNS hostname in /opt/demo/js/index.js.
2. Create basho_bench configs for your Riak nodes in /opt/basho_bench/config.  Each node should get two configs, one for reads and one for writes.  Read configs should be named riak_X.verify, which write configs should be named riak_X.write.
3. Update the node_count variable in /opt/app/load_test.sh with your number of Riak nodes.

**Viewing the GUI**

Your GUI will be accessible at http://<IP_or_hostname>/demo
