package lab.enterprise.platform.common.web.config;

import lab.enterprise.platform.common.web.filter.RequestContextFilter;
import org.springframework.boot.web.servlet.FilterRegistrationBean;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class WebFilterConfiguration {

    @Bean
    public FilterRegistrationBean<RequestContextFilter> customRequestContextFilter() {
        FilterRegistrationBean<RequestContextFilter> registrationBean = new FilterRegistrationBean<>();
        registrationBean.setFilter(new RequestContextFilter());
        registrationBean.setName("customRequestContextFilter");
        registrationBean.addUrlPatterns("/*");
        registrationBean.setOrder(Integer.MIN_VALUE);
        return registrationBean;
    }
}
