%{ for key, value in environment_variables }
export ${key}=${value}%{ endfor }