import jenkins.model.*
import org.datadog.jenkins.plugins.datadog.DatadogGlobalConfiguration

def j = Jenkins.getInstance()
def d = j.getDescriptor("org.datadog.jenkins.plugins.datadog.DatadogGlobalConfiguration")

d.setReportWith('DSD')
d.setTargetHost(System.getenv('DOGSTATSD_HOST_IP'))
d.setTargetPort(8125)

// If you want to collect logs
d.setTargetLogCollectionPort(8125)

// Save config
d.save()
