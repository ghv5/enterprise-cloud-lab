package lab.enterprise.user.controller;

import lab.enterprise.platform.common.core.api.ApiResponse;
import java.util.Map;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/users")
public class UserController {

    @GetMapping("/{id}")
    public ApiResponse<Map<String, Object>> getUser(@PathVariable Long id) {
        return ApiResponse.ok(Map.of(
            "id", id,
            "name", "demo-user-" + id,
            "status", "ACTIVE"
        ));
    }
}
