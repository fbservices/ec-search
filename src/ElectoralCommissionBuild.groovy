
// Start off in a tmp folder

def collection_name = "ElectoralCommission"

// Delete the folder if it exists already

new AntBuilder().delete('/tmp/funnelback-builder/' + collection_name)

// run git clone

Process p = "git clone git://github.com/fbservices/ec-search.git /tmp/funnelback-builder/".execute()

// copy the configuration files to the conf folder

new AntBuilder().copy(todir: "/opt/funnelback/conf/electoral-commission") {
	fileset(dir: "/tmp/funnelback-builder/" + collection_name + "/conf") {
		include(name: "**/*")
		exclude(name: "**/*")
	}
}

// copy the custom_bin files to the custom_bin folder

new AntBuilder().copy(todir: "/opt/funnelback/custom_bin") {
	fileset(dir: "/tmp/funnelback-builder/" + collection_name + "/custom_bin") {
		include(name: "**/*")
		exclude(name: "**/*")
	}
}

// copy the form plugins to the share/form_plugins folder

