package tn.tp7.backend;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Embeddable;
import jakarta.persistence.EmbeddedId;
import jakarta.persistence.MapsId;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;

import java.time.LocalDate;

@Entity
@Table(name = "app_user")
class AppUser {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    Integer id;
    @Column(nullable = false, unique = true, length = 100)
    String email;
    @Column(nullable = false, length = 100)
    String passwordHash;
    @Column(length = 20)
    String role;
    @ManyToOne @JoinColumn(name = "student_id", unique = true)
    Student student;
    @ManyToOne @JoinColumn(name = "teacher_id", unique = true)
    Teacher teacher;
}

@Entity
@Table(name = "classe")
class SchoolClass {
    @ManyToOne @JoinColumn(name="cod_dept") Department departement;
    @Id @Column(name = "cod_class", length = 30)
    String codClass;
    @Column(name = "nom_class", nullable = false, length = 100)
    String nomClass;
    @Column(name = "nbr_etud")
    Integer nbrEtud;
}

@Entity
@Table(name = "formation")
class Training {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    Integer id;
    @Column(nullable = false, length = 100)
    String nom;
    Integer duree;
}

@Entity
@Table(name = "etudiant")
class Student {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    Integer id;
    @Column(nullable = false, length = 100)
    String nom;
    @Column(nullable = false, length = 100)
    String prenom;
    @Column(name = "date_nais")
    LocalDate dateNais;
    @ManyToOne(fetch = FetchType.EAGER)
    @JoinColumn(name = "classe_cod_class")
    SchoolClass classe;
    @ManyToOne(fetch = FetchType.EAGER)
    @JoinColumn(name = "formation_id")
    Training formation;
}

@Entity @Table(name="departement") class Department {
 @Id @Column(name="cod_dept", length=30) String codDept;
 @Column(name="nom_dept", nullable=false, length=100) String nomDept;
}
@Entity @Table(name="matiere") class Subject {
 @Id @Column(name="cod_mat", length=30) String codMat;
 @Column(name="int_mat", nullable=false, length=100) String intMat;
 @Column(length=500) String description;
 @Column(name="has_tp") Boolean hasTp;
}
@Entity @Table(name="class_matiere") class ClassSubject {
 @Id @GeneratedValue(strategy=GenerationType.IDENTITY) Integer id;
 @ManyToOne(optional=false) @JoinColumn(name="cod_class") SchoolClass classe;
 @ManyToOne(optional=false) @JoinColumn(name="cod_mat") Subject matiere;
 @Column(nullable=false) Double coef;
 @Column(nullable=false) Integer chsm;
}
@Entity @Table(name="absence") class Absence {
 @Id @GeneratedValue(strategy=GenerationType.IDENTITY) Integer id;
 @ManyToOne(optional=false) @JoinColumn(name="nce") Student etudiant;
 @ManyToOne(optional=false) @JoinColumn(name="cod_mat") Subject matiere;
 @Column(name="date_a", nullable=false) LocalDate dateA;
 @Column(name="nha", nullable=false) Double nha;
}
@Entity @Table(name="note") class Grade {
 @EmbeddedId GradeId id;
 @MapsId("studentId") @ManyToOne(optional=false) @JoinColumn(name="nce") Student etudiant;
 @MapsId("subjectCode") @ManyToOne(optional=false) @JoinColumn(name="cod_mat") Subject matiere;
 @Column(name="valeur_note", nullable=false) Double valeurNote;
}
@Embeddable class GradeId implements java.io.Serializable {
 @Column(name="nce") Integer studentId;
 @Column(name="cod_mat") String subjectCode;
 public GradeId() {}
 public GradeId(Integer studentId, String subjectCode) { this.studentId=studentId; this.subjectCode=subjectCode; }
 public boolean equals(Object o) { return o instanceof GradeId g && java.util.Objects.equals(studentId,g.studentId)&&java.util.Objects.equals(subjectCode,g.subjectCode); }
 public int hashCode() { return java.util.Objects.hash(studentId,subjectCode); }
}

@Entity @Table(name="enseignant")
class Teacher {
 @Id @GeneratedValue(strategy=GenerationType.IDENTITY) Integer id;
 @Column(name="nom",nullable=false,length=100) String nom;
 @Column(name="prenom",nullable=false,length=100) String prenom;
}

@Entity @Table(name="enseignant_affectation", uniqueConstraints=@jakarta.persistence.UniqueConstraint(columnNames={"teacher_id","class_matiere_id"}))
class TeacherAssignment {
 @Id @GeneratedValue(strategy=GenerationType.IDENTITY) Integer id;
 @ManyToOne(optional=false) @JoinColumn(name="teacher_id") Teacher teacher;
 @ManyToOne(optional=false) @JoinColumn(name="class_matiere_id") ClassSubject classSubject;
}

@Entity @Table(name="note_evaluation", uniqueConstraints=@jakarta.persistence.UniqueConstraint(columnNames={"nce","cod_mat","annee_universitaire","semestre"}))
class AcademicGrade {
 @EmbeddedId AcademicGradeId id;
 @MapsId("studentId") @ManyToOne(optional=false) @JoinColumn(name="nce") Student etudiant;
 @MapsId("subjectCode") @ManyToOne(optional=false) @JoinColumn(name="cod_mat") Subject matiere;
 @Column(name="tp1") Double tp1;
 @Column(name="tp2") Double tp2;
 @Column(name="ds") Double ds;
 @Column(name="examen") Double examen;
}

@Embeddable class AcademicGradeId implements java.io.Serializable {
 @Column(name="nce") Integer studentId;
 @Column(name="cod_mat",length=30) String subjectCode;
 @Column(name="annee_universitaire",length=9) String academicYear;
 @Column(name="semestre") Integer semester;
 public AcademicGradeId() {}
 public AcademicGradeId(Integer studentId,String subjectCode,String academicYear,Integer semester){this.studentId=studentId;this.subjectCode=subjectCode;this.academicYear=academicYear;this.semester=semester;}
 public boolean equals(Object o){return o instanceof AcademicGradeId g&&java.util.Objects.equals(studentId,g.studentId)&&java.util.Objects.equals(subjectCode,g.subjectCode)&&java.util.Objects.equals(academicYear,g.academicYear)&&java.util.Objects.equals(semester,g.semester);}
 public int hashCode(){return java.util.Objects.hash(studentId,subjectCode,academicYear,semester);}
}

