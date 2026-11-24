package tn.tp7.backend;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

import java.util.UUID;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest(properties = {"spring.datasource.url=jdbc:h2:mem:tp7test;DB_CLOSE_DELAY=-1", "spring.jpa.hibernate.ddl-auto=create-drop", "app.security.enabled=false"})
@AutoConfigureMockMvc
class BackendIntegrationTest {
    @Autowired MockMvc http;
    @Autowired DepartmentRepository departments;
    @Test void authDoesNotExposePasswordAndRejectsWrongPassword() throws Exception {
        String email = UUID.randomUUID() + "@example.test";
        MvcResult result = sendPost("/register", "{\"email\":\"" + email + "\",\"password\":\"test-only-password\"}", 201);
        String user = result.getResponse().getContentAsString();
        assertThat(user).contains(email, "\"id\"").doesNotContain("password");
        sendPost("/login", "{\"email\":\"" + email + "\",\"password\":\"test-only-password\"}", 200);
        sendPost("/login", "{\"email\":\"" + email + "\",\"password\":\"wrong-password\"}", 401);
    }

    @Test void classTrainingAndStudentSupportCrud() throws Exception {
        String oldCode = "T-" + UUID.randomUUID().toString().substring(0, 8);
        String code = oldCode + "R";
        String deptCode = "D-" + UUID.randomUUID().toString().substring(0, 8);
        Department department = new Department(); department.codDept = deptCode; department.nomDept = "Département test"; departments.save(department);
        sendPost("/classes", "{\"codClass\":\"" + oldCode + "\",\"nomClass\":\"Classe test\",\"codDept\":\"" + deptCode + "\"}", 200);
        http.perform(get("/classes")).andExpect(status().isOk());
        http.perform(put("/classes/{code}", oldCode).contentType(MediaType.APPLICATION_JSON)
                .content("{\"codClass\":\"" + code + "\",\"nomClass\":\"Classe modifiée\",\"codDept\":\"" + deptCode + "\"}")).andExpect(status().isOk());

        String training = sendPost("/formations", "{\"nom\":\"Formation test\",\"duree\":10}", 200)
                .getResponse().getContentAsString();
        int trainingId = idFrom(training);
        http.perform(get("/formations")).andExpect(status().isOk());
        http.perform(put("/formations/{id}", trainingId).contentType(MediaType.APPLICATION_JSON)
                .content("{\"nom\":\"Formation modifiée\",\"duree\":12}")).andExpect(status().isOk());

        String student = sendPost("/etudiants", "{\"nom\":\"Test\",\"prenom\":\"TP7\",\"classe\":{\"codClass\":\"" + code + "\"},\"formation\":{\"id\":" + trainingId + "}}", 200)
                .getResponse().getContentAsString();
        int studentId = idFrom(student);
        assertThat(student).contains("\"codClass\":\"" + code + "\"", "\"nomClass\":\"Classe modifiée\"",
                "\"nom\":\"Formation modifiée\"");
        http.perform(get("/etudiants")).andExpect(status().isOk());
        http.perform(put("/etudiants/{id}", studentId).contentType(MediaType.APPLICATION_JSON)
                .content("{\"nom\":\"Modifié\",\"prenom\":\"TP7\",\"classe\":{\"codClass\":\"" + code + "\"},\"formation\":{\"id\":" + trainingId + "}}"))
                .andExpect(status().isOk());
        http.perform(delete("/etudiants/{id}", studentId)).andExpect(status().isOk());
        http.perform(delete("/formations/{id}", trainingId)).andExpect(status().isOk());
        http.perform(delete("/classes/{code}", code)).andExpect(status().isOk());
    }

    private MvcResult sendPost(String path, String body, int expectedStatus) throws Exception {
        return http.perform(post(path).contentType(MediaType.APPLICATION_JSON).content(body))
                .andExpect(status().is(expectedStatus)).andReturn();
    }
    private int idFrom(String json) {
        Matcher matcher = Pattern.compile("\\\"id\\\"\\s*:\\s*(\\d+)").matcher(json);
        if (!matcher.find()) throw new AssertionError("Response has no id: " + json);
        return Integer.parseInt(matcher.group(1));
    }
}
