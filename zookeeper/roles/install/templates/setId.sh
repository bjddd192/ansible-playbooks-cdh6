#/bin/sh
{% for ip in groups['zookeeper'] %}
{% if ip == inventory_hostname %}
echo {{ loop.index }} > {{ zookeeper_data_path }}/myid
{% endif %}
{% endfor %}
