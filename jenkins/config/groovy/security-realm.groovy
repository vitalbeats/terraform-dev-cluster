import jenkins.model.Jenkins
import hudson.security.FullControlOnceLoggedInAuthorizationStrategy
import org.jenkinsci.plugins.googlelogin.GoogleOAuth2SecurityRealm

def realm = new GoogleOAuth2SecurityRealm(System.getenv('GOOGLE_CLIENT_ID'), System.getenv('GOOGLE_CLIENT_SECRET'), System.getenv('GOOGLE_CLIENT_DOMAINS'))
Jenkins.instance.setSecurityRealm(realm)
def strategy = new FullControlOnceLoggedInAuthorizationStrategy()
strategy.setAllowAnonymousRead(false)
Jenkins.instance.setAuthorizationStrategy(strategy)
Jenkins.instance.save()