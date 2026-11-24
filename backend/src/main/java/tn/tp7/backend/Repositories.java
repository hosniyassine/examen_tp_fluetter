package tn.tp7.backend;

import org.springframework.data.jpa.repository.JpaRepository;

interface UserRepository extends JpaRepository<AppUser, Integer> {
    boolean existsByEmail(String email);
    boolean existsByTeacherId(Integer teacherId);
    java.util.Optional<AppUser> findByEmail(String email);
}
interface TeacherRepository extends JpaRepository<Teacher, Integer> {}
interface TeacherAssignmentRepository extends JpaRepository<TeacherAssignment, Integer> {
    boolean existsByTeacherIdAndClassSubjectId(Integer teacherId, Integer classSubjectId);
    boolean existsByClassSubjectId(Integer classSubjectId);
    boolean existsByClassSubjectMatiereCodMat(String codMat);
    java.util.List<TeacherAssignment> findAllByTeacherId(Integer teacherId);
    boolean existsByTeacherId(Integer teacherId);
}
interface AcademicGradeRepository extends JpaRepository<AcademicGrade, AcademicGradeId> {
    java.util.List<AcademicGrade> findAllByEtudiantIdAndIdAcademicYearAndIdSemester(Integer studentId, String year, Integer semester);
    java.util.List<AcademicGrade> findAllByEtudiantClasseCodClassAndIdAcademicYearAndIdSemester(String codClass, String year, Integer semester);
    java.util.Optional<AcademicGrade> findByEtudiantIdAndMatiereCodMatAndIdAcademicYearAndIdSemester(Integer studentId, String codMat, String year, Integer semester);
    boolean existsByMatiereCodMat(String codMat);
    boolean existsByEtudiantClasseCodClassAndMatiereCodMat(String codClass, String codMat);
}

interface SchoolClassRepository extends JpaRepository<SchoolClass, String> {
    boolean existsByDepartementCodDept(String codDept);
}
interface TrainingRepository extends JpaRepository<Training, Integer> {}
interface StudentRepository extends JpaRepository<Student, Integer> {
    long countByClasseCodClass(String codClass);
    java.util.List<Student> findAllByClasseCodClass(String codClass);
}
interface DepartmentRepository extends org.springframework.data.jpa.repository.JpaRepository<Department,String> {}
interface SubjectRepository extends org.springframework.data.jpa.repository.JpaRepository<Subject,String> {}
interface ClassSubjectRepository extends org.springframework.data.jpa.repository.JpaRepository<ClassSubject,Integer> {
    java.util.List<ClassSubject> findAllByClasseCodClass(String codClass);
    java.util.List<ClassSubject> findAllByMatiereCodMat(String codMat);
    java.util.Optional<ClassSubject> findByClasseCodClassAndMatiereCodMat(String codClass, String codMat);
    boolean existsByMatiereCodMat(String codMat);
    boolean existsByClasseCodClassAndMatiereCodMat(String codClass, String codMat);
    boolean existsByClasseCodClass(String codClass);
}
interface AbsenceRepository extends org.springframework.data.jpa.repository.JpaRepository<Absence,Integer> {
 java.util.List<Absence> findAllByEtudiantId(Integer id);
 java.util.Optional<Absence> findByEtudiantIdAndMatiereCodMatAndDateA(Integer id, String codMat, java.time.LocalDate dateA);
 boolean existsByMatiereCodMat(String codMat);
 boolean existsByEtudiantClasseCodClassAndMatiereCodMat(String codClass, String codMat);
}
interface GradeRepository extends org.springframework.data.jpa.repository.JpaRepository<Grade,GradeId> {
    boolean existsByMatiereCodMat(String codMat);
    boolean existsByEtudiantClasseCodClassAndMatiereCodMat(String codClass, String codMat);
}

