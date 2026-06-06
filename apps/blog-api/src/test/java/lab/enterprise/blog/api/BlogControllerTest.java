package lab.enterprise.blog.api;

import static org.hamcrest.Matchers.hasSize;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import lab.enterprise.blog.BlogApiApplication;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.web.servlet.MockMvc;

@SpringBootTest(classes = BlogApiApplication.class)
@AutoConfigureMockMvc
class BlogControllerTest {

  @Autowired
  private MockMvc mockMvc;

  @Test
  void postsReturnsSuccessEnvelope() throws Exception {
    mockMvc.perform(get("/api/posts"))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.success").value(true))
        .andExpect(jsonPath("$.data", hasSize(2)))
        .andExpect(jsonPath("$.meta.version").exists());
  }

  @Test
  void prometheusEndpointIsExposed() throws Exception {
    mockMvc.perform(get("/actuator/prometheus"))
        .andExpect(status().isOk())
        .andExpect(content().string(org.hamcrest.Matchers.containsString("jvm_memory_used_bytes")));
  }
}
