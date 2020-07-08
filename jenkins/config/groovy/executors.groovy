import jenkins.model.*

Jenkins.instance.agentProtocols = ["JNLP4-connect", "Ping"] as Set
Jenkins.instance.crumbIssuer = new hudson.security.csrf.DefaultCrumbIssuer(true)
Jenkins.instance.injector.getInstance(jenkins.security.s2m.AdminWhitelistRule.class).setMasterKillSwitch(false)
Jenkins.instance.setNumExecutors(0)

def jlc = JenkinsLocationConfiguration.get()
jlc.setUrl("https://jenkins.vitalbeats.dev")
jlc.setAdminAddress("[Vital Beats Engineering] <engineering@vitalbeats.com>")
jlc.save() 
