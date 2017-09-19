from Looker import produce_models
import json
with open("data.json") as file:
  print(
    produce_models(
      'models',
      json.load(
        file
      )
    )
  )


# program_users = relationship('ProgramUser', secondary='join(VerificationCode, ProgramUser, VerificationCode.id == ProgramUser.verification_code_id).join(VerificationCodeTemplate, VerificationCodeTemplate.id == VerificationCode.verification_code_template_id)', primaryjoin="VerificationCodeTemplate.hospital_id == Hospital.id", viewonly=True)
